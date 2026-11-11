-- shared/TestHooks.lua
--
-- Observability / test-harness API, shipped as part of the template so every
-- game gets it for free — no per-game debug code needed. Used by agents for
-- live verification (see the `roblox-playtest` skill for how it's driven);
-- also safe to use for your own manual debugging.
--
-- Server-authoritative (CLAUDE.md "Server Authority"): call these from
-- server-side code. Events are stored in the DataModel
-- (ServerStorage.TestHooksEvents), not in this module's local state, so any
-- server-side context reads the same events — including an execute_luau call
-- whose require() returns a fresh copy of this module. Clients can't see
-- ServerStorage: on a client, log() only prints and getEvents() returns {}.
--
-- Minimum setup for a builder:
--   1. require() this module wherever you already require GameConfig.
--   2. Call TestHooks.tagInteractable(instance) once, right where you create
--      anything a player can walk up to and enter/use/collect.
--   3. Call TestHooks.log(category, message, data) at meaningful state
--      transitions (destroyed, collected, phase changed, scored) instead of
--      (or alongside) a plain warn()/print().
-- That's it — dumpState(), getEvents(), and teleportNear() all work for free
-- once those two conventions are followed.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TestHooks = {}

local DEFAULT_TAG = "Interactable"
-- The store keeps the newest MAX_EVENTS events; older ones are dropped. A long test that
-- logs a lot should read its events as it goes (take `since` before each action).
local MAX_EVENTS = 10000
TestHooks.MAX_EVENTS = MAX_EVENTS
local STORE_NAME = "TestHooksEvents"
local MAX_DATA_DEPTH = 6

-- The shared event store: one Configuration child per event, named by its
-- sequence number. Folder attributes NextSeq/OldestSeq let any module copy
-- append and trim without scanning.
local function getStore(): Instance?
	if not RunService:IsServer() then
		return nil
	end
	local ServerStorage = game:GetService("ServerStorage")
	local store = ServerStorage:FindFirstChild(STORE_NAME)
	if not store then
		store = Instance.new("Folder")
		store.Name = STORE_NAME
		store:SetAttribute("NextSeq", 1)
		store:SetAttribute("OldestSeq", 1)
		store.Parent = ServerStorage
	end
	return store
end

local function isArray(t: { [any]: any }): boolean
	local count = 0
	for _ in pairs(t) do
		count += 1
	end
	return count == #t
end

-- Convert arbitrary event data to JSON-safe values: Vector3, Instances,
-- functions etc. become strings; tables are copied up to MAX_DATA_DEPTH.
local function toPlain(value: any, depth: number): any
	local kind = type(value)
	if kind == "string" or kind == "boolean" or value == nil then
		return value
	elseif kind == "number" then
		return (value == value and value ~= math.huge and value ~= -math.huge) and value or tostring(value)
	elseif kind == "table" then
		if depth >= MAX_DATA_DEPTH then
			return tostring(value)
		end
		local array = isArray(value)
		local out = {}
		for k, v in pairs(value) do
			out[array and k or tostring(k)] = toPlain(v, depth + 1)
		end
		return out
	end
	return tostring(value)
end

local function encodeData(data: any): string
	local ok, json = pcall(HttpService.JSONEncode, HttpService, { value = toPlain(data, 0) })
	return ok and json or HttpService:JSONEncode({ value = tostring(data) })
end

local function decodeData(json: string?): any
	if not json then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	-- `ok and decoded.value or json` would turn nil/false data into the raw JSON string.
	if ok and type(decoded) == "table" then
		return decoded.value
	end
	return json
end

local function trim(store: Instance)
	local nextSeq, oldest = store:GetAttribute("NextSeq"), store:GetAttribute("OldestSeq")
	while nextSeq - oldest > MAX_EVENTS do
		local child = store:FindFirstChild(tostring(oldest))
		if child then
			child:Destroy()
		end
		oldest += 1
	end
	store:SetAttribute("OldestSeq", oldest)
end

-- Tag an instance as interactable (enterable/usable/collectible — anything a
-- player can walk up to and do something with). One line, right where you
-- create the entity. Enables generic tooling (teleportNear, dumpState) to
-- find it without knowing anything else about your game.
function TestHooks.tagInteractable(instance, tag)
	CollectionService:AddTag(instance, tag or DEFAULT_TAG)
end

-- Record a structured, filterable event. Call this at state transitions a
-- tester would care about, instead of (or in addition to) a plain warn() —
-- raw console output gets drowned out by unrelated noise fast; this doesn't.
-- Still prints too, so it's a strict addition, not a replacement for
-- anything non-test code already relies on.
local quietCategories: { [string]: boolean } = {}

function TestHooks.log(category, message, data)
	if not quietCategories[tostring(category)] then
		print(string.format("[TestHooks:%s] %s", category, message))
	end
	local store = getStore()
	if not store then
		return
	end
	local seq = store:GetAttribute("NextSeq")
	local event = Instance.new("Configuration")
	event.Name = tostring(seq)
	event:SetAttribute("Time", os.clock())
	event:SetAttribute("Category", tostring(category))
	event:SetAttribute("Message", tostring(message))
	event:SetAttribute("Data", encodeData(data))
	event.Parent = store
	store:SetAttribute("NextSeq", seq + 1)
	trim(store)
end

-- Keep recording a high-volume category (one event per kill) without printing it, so Output
-- stays readable. setQuiet(category, false) prints it again. Applies to logs made through
-- this module copy: call it from the game code that logs the category.
function TestHooks.setQuiet(category: string, quiet: boolean?)
	quietCategories[category] = if quiet == false then nil else true
end

-- Return recorded events at or after sinceTime (an os.clock() value from an
-- earlier TestHooks call or sample), optionally filtered to one category.
-- Omit both args for the full buffer.
function TestHooks.getEvents(sinceTime, category)
	local store = getStore()
	if not store then
		return {}
	end
	local children = store:GetChildren()
	table.sort(children, function(a, b)
		return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
	end)
	local result = {}
	for _, child in ipairs(children) do
		local time, cat = child:GetAttribute("Time"), child:GetAttribute("Category")
		if (sinceTime == nil or time >= sinceTime) and (category == nil or cat == category) then
			table.insert(result, {
				time = time,
				category = cat,
				message = child:GetAttribute("Message"),
				data = decodeData(child:GetAttribute("Data")),
			})
		end
	end
	return result
end

-- Wait until an event in `category` (and with `message`, if given) is logged at or after
-- `sinceTime`, then return it; nil after `timeout` seconds (default 10). Take sinceTime with
-- os.clock() *before* the action, then wait for the action's own event. Never wait for a
-- state (attribute, phase) after an action: it may already hold from before, so the wait
-- returns before the action has had any effect.
function TestHooks.waitForEvent(sinceTime: number, category: string, message: string?, timeout: number?)
	local deadline = os.clock() + (timeout or 10)
	repeat
		for _, event in ipairs(TestHooks.getEvents(sinceTime, category)) do
			if message == nil or event.message == message then
				return event
			end
		end
		task.wait(0.1)
	until os.clock() > deadline
	return nil
end

local function tagPosition(inst)
	if inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

-- Generic state snapshot: every Player's attributes, plus every instance
-- tagged with `tags` (default just "Interactable") and its attributes.
-- Needs zero per-game code — it only relies on the tagging/attributes
-- conventions CLAUDE.md already requires, not any game-specific knowledge.
function TestHooks.dumpState(tags)
	tags = tags or { DEFAULT_TAG }
	local snapshot = { players = {}, tagged = {} }

	for _, player in ipairs(Players:GetPlayers()) do
		snapshot.players[player.Name] = player:GetAttributes()
	end

	for _, tag in ipairs(tags) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			table.insert(snapshot.tagged, {
				name = inst.Name,
				tag = tag,
				position = tagPosition(inst),
				attributes = inst:GetAttributes(),
			})
		end
	end

	return snapshot
end

-- Move `player`'s character next to the nearest instance tagged `tag`
-- (default "Interactable"). Returns (true, theInstance) or (false, nil) if
-- no tagged instance exists. Test-harness setup only — never call this from
-- real game logic; it's how a critic/tester reaches a scenario fast without
-- fighting navigation tools or needing to know entity names in advance.
function TestHooks.teleportNear(player, tag)
	tag = tag or DEFAULT_TAG
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, nil
	end

	local nearest, nearestDist = nil, math.huge
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		local pos = tagPosition(inst)
		if pos then
			local d = (pos - hrp.Position).Magnitude
			if d < nearestDist then
				nearest, nearestDist = inst, d
			end
		end
	end

	if not nearest then
		return false, nil
	end

	local pos = tagPosition(nearest)
	hrp.CFrame = CFrame.new(pos + Vector3.new(2, 0, 0))
	return true, nearest
end

-- Dev commands: let a test act on a live game's private state (set currency, force a save,
-- run the smoke test). execute_luau gets a fresh copy of every module, so it can't reach the
-- running game's tables; a registered command runs the registering copy's function.
-- Two ways to call one:
--   * runCommand(name, ...) from server-side execute_luau: a BindableFunction in
--     ServerStorage.TestHooksCommands. Fails when execute_luau runs sandboxed (no "Network"
--     capability: Bindable invokes and require of game modules are refused).
--   * Attributes, which work even sandboxed, on the server and on a client: set
--     "Dev_<name>_Done" = false, then "Dev_<name>" = a JSON array of arguments (or any other
--     string, passed as the one argument) on ServerStorage (server) or the LocalPlayer
--     (client). Poll "Dev_<name>_Done" until true and read "Dev_<name>_Result": the return
--     value (non-strings as JSON), or "error: ...". Arguments are plain values, so a handler
--     meant for this route takes plain values (a player's Name, not the Player).
-- Studio only: outside Studio registerCommand does nothing and runCommand errors.
local COMMANDS_NAME = "TestHooksCommands"
local DEV_PREFIX = "Dev_"
TestHooks.DEV_PREFIX = DEV_PREFIX

local function commandsFolder(create: boolean): Instance?
	local ServerStorage = game:GetService("ServerStorage")
	local folder = ServerStorage:FindFirstChild(COMMANDS_NAME)
	if not folder and create then
		folder = Instance.new("Folder")
		folder.Name = COMMANDS_NAME
		folder.Parent = ServerStorage
	end
	return folder
end

local function decodeArgs(request: string): { any }
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, request)
	if ok and type(decoded) == "table" and isArray(decoded) then
		return decoded
	end
	return { request }
end

local function formatResult(ok: boolean, result: any): string
	if not ok then
		return "error: " .. tostring(result)
	elseif type(result) == "string" then
		return result
	end
	local plain = toPlain(result, 0)
	local encoded, json = pcall(HttpService.JSONEncode, HttpService, plain)
	return if encoded then json else tostring(result)
end

local attributeConnections: { [string]: RBXScriptConnection } = {}

-- Answers "Dev_<name>" requests on `target`; each request runs fn once, in its own thread.
local function listenOnAttribute(target: Instance, name: string, fn: (...any) -> ...any)
	local key = DEV_PREFIX .. name
	if attributeConnections[key] then
		attributeConnections[key]:Disconnect()
	end
	attributeConnections[key] = target:GetAttributeChangedSignal(key):Connect(function()
		local request = target:GetAttribute(key)
		if request == nil then
			return
		end
		target:SetAttribute(key .. "_Done", false)
		task.spawn(function()
			local ok, result = pcall(fn, table.unpack(decodeArgs(tostring(request))))
			target:SetAttribute(key .. "_Result", formatResult(ok, result))
			target:SetAttribute(key, nil)
			target:SetAttribute(key .. "_Done", true)
		end)
	end)
end

-- Register a Studio-only test command, e.g. in a service's or controller's init():
--   TestHooks.registerCommand("setCrumbs", function(playerName, n) ... end)
-- On the server it answers runCommand and ServerStorage attributes; on a client, the
-- LocalPlayer's attributes. Registering the same name again replaces it.
function TestHooks.registerCommand(name: string, fn: (...any) -> ...any)
	if not RunService:IsStudio() then
		return
	end
	if not RunService:IsServer() then
		listenOnAttribute(Players.LocalPlayer, name, fn)
		return
	end
	listenOnAttribute(game:GetService("ServerStorage"), name, fn)
	local folder = commandsFolder(true) :: Instance
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local bindable = Instance.new("BindableFunction")
	bindable.Name = name
	bindable.OnInvoke = fn
	bindable.Parent = folder
end

-- Run a registered command from any server-side copy (e.g. execute_luau on Server):
--   TestHooks.runCommand("setCrumbs", "Player1", 5000)
function TestHooks.runCommand(name: string, ...: any): ...any
	assert(RunService:IsStudio(), "TestHooks.runCommand: Studio only")
	local folder = commandsFolder(false)
	local bindable = folder and folder:FindFirstChild(name)
	if not bindable then
		local known = {}
		for _, child in ipairs(folder and folder:GetChildren() or {}) do
			table.insert(known, child.Name)
		end
		error(string.format("TestHooks.runCommand: unknown command %q (registered: %s)", name, table.concat(known, ", ")))
	end
	return (bindable :: BindableFunction):Invoke(...)
end

-- Silence the game in Studio during agent test runs (smoke tests, playtests, fast matches):
-- every client's shared/TestAudio watcher (started by ServiceLoader) zeroes all sound while
-- ReplicatedStorage's TestHooksMuted attribute is true, and restores it when cleared. Players'
-- settings and the published game are never touched. Server side, from any copy:
--   TestHooks.muteAudio(true)   -- before a test run; muteAudio(false) to hear it again
local MUTE_ATTRIBUTE = "TestHooksMuted"
TestHooks.MUTE_ATTRIBUTE = MUTE_ATTRIBUTE

function TestHooks.muteAudio(on: boolean?)
	assert(RunService:IsStudio(), "TestHooks.muteAudio: Studio only")
	game:GetService("ReplicatedStorage"):SetAttribute(MUTE_ATTRIBUTE, on ~= false)
end

return TestHooks
