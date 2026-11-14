--!strict
-- A mock DataStore for development, Lune tests and the Tier 2 smoke test. Framework file: fix
-- it here, game-agnostically, when a game finds it behaves differently from the real service
-- (CLAUDE.md, *Persistence*, and decisions/0001-publish-late.md).
--
-- NEVER part of a shipped game. It keeps everything in memory (nothing survives a server stop)
-- and may only be used (a) in tests, and (b) by a game's DataService as the Studio fallback
-- when the real DataStore is unavailable, through MockDataStore.newForStudio(), which refuses to
-- run outside Studio. tests/framework.lua fails if any other game file requires this module.
--
-- It copies the real service's rules that games trip over:
--   * keys: non-empty strings, at most 50 characters (errors 101, 102);
--   * values: must serialize. No functions, userdata, Roblox datatypes, NaN or infinity, cycles,
--     mixed array/dictionary tables, holes in arrays, or values over 4,194,304 characters
--     (errors 103-105). Values are deep-copied in and out, so code under test never shares a
--     table with the store;
--   * UpdateAsync(key, transform) runs transform(old), and if the stored value changed between
--     the read and the write it runs transform again with the new value (like the real
--     service); returning nil cancels the write. Real transforms may not yield; this mock
--     cannot enforce that, so don't yield in one;
--   * GetAsync / UpdateAsync / SetAsync / IncrementAsync / RemoveAsync return the value and a
--     key-info table ({ Version, CreatedTime, UpdatedTime }).
-- It cannot copy: real latency, per-minute request budgets (use throttle()), cross-server
-- behavior (use interleave()), or exact serialized sizes (the size check is an estimate).
--
-- Fault injection (tests and dev): failNext, throttle, interleave, onCall. Counters: reads,
-- writes, `data` (the raw table, for assertions: don't write to it).

local MockDataStore = {}
MockDataStore.__index = MockDataStore

local MAX_KEY_LENGTH = 50
local MAX_VALUE_SIZE = 4194304
local MAX_DEPTH = 128
local MAX_UPDATE_ATTEMPTS = 5

export type KeyInfo = { Version: string, CreatedTime: number, UpdatedTime: number }
export type Store = typeof(setmetatable(
	{} :: {
		data: { [string]: any },
		keyInfo: { [string]: KeyInfo },
		reads: number,
		writes: number,
		failures: number,
		failMessage: string,
		throttleLimit: number?,
		throttleWindow: number,
		throttleClock: (() -> number)?,
		throttleStamps: { number },
		interleaveFn: ((key: string) -> ())?,
		callHook: ((kind: string, key: string) -> ())?,
		versionCounter: number,
		maxValueSize: number,
	},
	MockDataStore
))

-- ---- Serialization rules -----------------------------------------------------

local function isArray(t: { [any]: any }): (boolean, number)
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
			return false, 0
		end
		n += 1
	end
	for i = 1, n do
		if t[i] == nil then
			return false, 0 -- a hole: the real service rejects it
		end
	end
	return true, n
end

-- Deep-copies `value`, raising the real service's errors for anything that would not
-- serialize. Returns the copy and an estimate of its serialized size.
local function copyValue(value: any, depth: number, seen: { [any]: boolean }): (any, number)
	local kind = type(value)
	if kind == "string" then
		return value, #value + 2
	elseif kind == "boolean" then
		return value, 5
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			error("104: Can't store " .. tostring(value) .. " in DataStore", 0)
		end
		return value, #tostring(value)
	elseif kind == "table" then
		if depth > MAX_DEPTH then
			error("104: Can't store a table nested deeper than " .. MAX_DEPTH .. " in DataStore", 0)
		end
		if seen[value] then
			error("104: Can't store a table that contains itself in DataStore", 0)
		end
		seen[value] = true
		local out: { [any]: any } = {}
		local size = 2
		local array, count = isArray(value)
		if array then
			for i = 1, count do
				local copy, s = copyValue(value[i], depth + 1, seen)
				out[i] = copy
				size += s + 1
			end
		else
			for k, v in pairs(value) do
				if type(k) ~= "string" then
					error("104: Can't store a table that mixes arrays and dictionaries, or has holes, in DataStore", 0)
				end
				local copy, s = copyValue(v, depth + 1, seen)
				out[k] = copy
				size += #k + 3 + s + 1
			end
		end
		seen[value] = nil
		return out, size
	end
	-- functions, userdata, threads, Roblox datatypes (Vector3, Color3, Instance ...)
	error("103: Can't allow " .. typeof(value) .. " in DataStore", 0)
end

local function validateKey(key: any)
	if type(key) ~= "string" then
		error("101: Key name must be a string", 0)
	end
	if key == "" then
		error("101: Key name can't be empty.", 0)
	end
	if #key > MAX_KEY_LENGTH then
		error("102: Key name exceeds the " .. MAX_KEY_LENGTH .. " character limit.", 0)
	end
end

local function plainCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = plainCopy(v)
	end
	return out
end

-- ---- Construction ------------------------------------------------------------

function MockDataStore.new(): Store
	return setmetatable({
		data = {},
		keyInfo = {},
		reads = 0,
		writes = 0,
		failures = 0,
		failMessage = "MockDataStore: injected failure",
		throttleLimit = nil,
		throttleWindow = 60,
		throttleClock = nil,
		throttleStamps = {},
		interleaveFn = nil,
		callHook = nil,
		versionCounter = 0,
		maxValueSize = MAX_VALUE_SIZE,
	}, MockDataStore)
end

-- The only way game code may create a mock outside tests: raises unless running in Studio.
function MockDataStore.newForStudio(): Store
	local ok, studio = pcall(function()
		return (game :: any):GetService("RunService"):IsStudio()
	end)
	if not (ok and studio == true) then
		error("MockDataStore.newForStudio: refusing to run outside Studio (it would lose player data)", 2)
	end
	return MockDataStore.new()
end

-- A stand-in for DataStoreService: GetDataStore(name, scope) returns one mock per name+scope.
function MockDataStore.newService()
	local stores: { [string]: Store } = {}
	local service = { IsMock = true }
	function service.GetDataStore(_self: any, name: string, scope: string?): Store
		local id = name .. "/" .. (scope or "global")
		if not stores[id] then
			stores[id] = MockDataStore.new()
		end
		return stores[id]
	end
	return service
end

-- ---- Fault injection -----------------------------------------------------------

-- The next `count` calls (reads or writes) raise `message`, like an offline store.
-- math.huge means always; 0 turns it off.
function MockDataStore.failNext(self: Store, count: number, message: string?)
	self.failures = count
	self.failMessage = message or "MockDataStore: injected failure"
end

-- Allows `limit` calls per `windowSeconds` (default 60), then raises a throttle error until the
-- window moves on. `clock` returns seconds (os.clock in Lune, a fake clock in tests).
-- limit = nil turns it off.
function MockDataStore.throttle(self: Store, limit: number?, clock: (() -> number)?, windowSeconds: number?)
	self.throttleLimit = limit
	self.throttleClock = clock or os.clock
	self.throttleWindow = windowSeconds or 60
	self.throttleStamps = {}
end

-- `fn(key)` runs inside the next UpdateAsync, after its read and before its write, so a test
-- can write the key "from another server": the real service then re-runs the transform with
-- the new value, and so does this one. Use it to test session locks and lost-update handling.
-- Fires once, then clears.
function MockDataStore.interleave(self: Store, fn: ((key: string) -> ())?)
	self.interleaveFn = fn
end

-- `fn(kind, key)` runs at the start of every call ("get", "update", "set", "increment",
-- "remove"); raise to fail the call, or yield (in the Studio fallback) to add latency.
function MockDataStore.onCall(self: Store, fn: ((kind: string, key: string) -> ())?)
	self.callHook = fn
end

function MockDataStore._enter(self: Store, kind: string, key: any)
	if self.callHook then
		self.callHook(kind, key)
	end
	if self.failures > 0 then
		self.failures -= 1
		error(self.failMessage, 0)
	end
	local limit = self.throttleLimit
	if limit then
		local clock = self.throttleClock :: () -> number
		local now = clock()
		local kept = {}
		for _, stamp in ipairs(self.throttleStamps) do
			if now - stamp < self.throttleWindow then
				table.insert(kept, stamp)
			end
		end
		self.throttleStamps = kept
		if #kept >= limit then
			error("304: request dropped. Request was throttled but queue was full.", 0)
		end
		table.insert(kept, now)
	end
	validateKey(key)
end

-- ---- The DataStore API ----------------------------------------------------------

function MockDataStore._info(self: Store, key: string): KeyInfo
	return plainCopy(self.keyInfo[key])
end

function MockDataStore._commit(self: Store, key: string, value: any)
	local copy, size = copyValue(value, 1, {})
	if size > self.maxValueSize then
		error("105: Serialized value exceeds " .. self.maxValueSize .. " limit.", 0)
	end
	self.versionCounter += 1
	local now = os.time()
	local info = self.keyInfo[key]
	self.data[key] = copy
	self.keyInfo[key] = {
		Version = tostring(self.versionCounter),
		CreatedTime = if info then info.CreatedTime else now,
		UpdatedTime = now,
	}
	self.writes += 1
end

function MockDataStore.GetAsync(self: Store, key: string): (any, KeyInfo?)
	self:_enter("get", key)
	self.reads += 1
	if self.data[key] == nil then
		return nil, nil
	end
	return plainCopy(self.data[key]), self:_info(key)
end

function MockDataStore.SetAsync(self: Store, key: string, value: any, _userIds: any?, _options: any?): string
	self:_enter("set", key)
	if value == nil then
		error("103: Can't allow nil in DataStore", 0)
	end
	self:_commit(key, value)
	return self.keyInfo[key].Version
end

-- `transform(old)` returns the new value, or nil to cancel (the stored value stays and is
-- returned). Re-runs transform if the key changed under it (see interleave).
function MockDataStore.UpdateAsync(self: Store, key: string, transform: (any, KeyInfo?) -> any): (any, KeyInfo?)
	self:_enter("update", key)
	for _ = 1, MAX_UPDATE_ATTEMPTS do
		local readVersion = if self.keyInfo[key] then self.keyInfo[key].Version else nil
		local new = transform(plainCopy(self.data[key]), if readVersion then self:_info(key) else nil)
		local hook = self.interleaveFn
		if hook then
			self.interleaveFn = nil
			hook(key)
		end
		local nowVersion = if self.keyInfo[key] then self.keyInfo[key].Version else nil
		if nowVersion == readVersion then
			if new == nil then
				return plainCopy(self.data[key]), if nowVersion then self:_info(key) else nil
			end
			self:_commit(key, new)
			return plainCopy(self.data[key]), self:_info(key)
		end
		-- the key changed since the read: run the transform again on the new value
	end
	error("304: UpdateAsync gave up after repeated conflicting writes", 0)
end

function MockDataStore.IncrementAsync(self: Store, key: string, delta: number?): (number, KeyInfo)
	self:_enter("increment", key)
	local old = self.data[key]
	if old ~= nil and type(old) ~= "number" then
		error("104: Can't increment a non-number value in DataStore", 0)
	end
	local step = delta or 1
	if step % 1 ~= 0 or (old ~= nil and old % 1 ~= 0) then
		error("104: IncrementAsync works on integers only", 0)
	end
	self:_commit(key, (old or 0) + step)
	return self.data[key], self:_info(key)
end

function MockDataStore.RemoveAsync(self: Store, key: string): (any, KeyInfo?)
	self:_enter("remove", key)
	local old, info = plainCopy(self.data[key]), if self.keyInfo[key] then self:_info(key) else nil
	self.data[key] = nil
	self.keyInfo[key] = nil
	if old ~= nil then
		self.writes += 1
	end
	return old, info
end

-- ---- Test helpers -----------------------------------------------------------------

function MockDataStore.keys(self: Store): { string }
	local out = {}
	for k in pairs(self.data) do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

-- Forgets everything and every injected fault, like a fresh server.
function MockDataStore.reset(self: Store)
	self.data = {}
	self.keyInfo = {}
	self.reads, self.writes, self.failures, self.versionCounter = 0, 0, 0, 0
	self.throttleLimit, self.interleaveFn, self.callHook = nil, nil, nil
	self.throttleStamps = {}
end

-- Lowers the value-size limit (default 4,194,304), so a test can reach it cheaply.
function MockDataStore.setMaxValueSize(self: Store, size: number)
	self.maxValueSize = size
end

return MockDataStore
