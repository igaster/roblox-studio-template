--!strict
-- Behavior every DataStore-like object must have for the framework's Persistence rules
-- (CLAUDE.md). Two groups:
--
--   StoreContract.basic(make, H)   works on ANY store: the mock, a game's wrapper, or the real
--                                  DataStore (run it in a Play session with a throwaway store
--                                  name, once, at the platform-hardening milestone: a
--                                  `[needs-published]` check). `make()` returns a fresh store,
--                                  or the same real store each time (keys are unique per call).
--   StoreContract.faults(make, H)  needs the mock's fault injection (failNext, throttle,
--                                  interleave); mock only.
--
-- `H` is anything with check(name, bool) and eq(name, actual, expected): the Lune harness
-- (tests/harness.lua) or a two-line adapter in a Play session (FrameworkSmokeTest has one).
-- Run against the mock by tests/framework.lua (Lune) and FrameworkSmokeTest (in-engine), so
-- a divergence between the two engines shows up. If the real service turns out to behave
-- differently, fix MockDataStore and add the case here.

local StoreContract = {}

export type Harness = {
	check: (name: string, cond: boolean) -> (),
	eq: (name: string, actual: any, expected: any) -> (),
}

local counter = 0
local function uniqueKey(label: string): string
	counter += 1
	return "contract_" .. label .. "_" .. counter .. "_" .. tostring(os.time() % 100000)
end

local function fails(fn: () -> any): boolean
	local ok = pcall(fn)
	return not ok
end

function StoreContract.basic(make: () -> any, H: Harness)
	local store = make()

	-- Reads and writes
	local k = uniqueKey("rw")
	H.eq("a missing key reads nil", (store:GetAsync(k)), nil)
	store:SetAsync(k, { Coins = 5, Items = { "a", "b" } })
	local got = store:GetAsync(k)
	H.eq("SetAsync then GetAsync round-trips a nested table", got.Coins, 5)
	H.eq("arrays round-trip in order", got.Items[2], "b")

	-- Copy semantics: the store never shares a table with the caller
	local mine = { Coins = 1 }
	local k2 = uniqueKey("copy")
	store:SetAsync(k2, mine)
	mine.Coins = 99
	H.eq("a stored value is a copy: later edits to the original do not reach the store", store:GetAsync(k2).Coins, 1)
	local read = store:GetAsync(k2)
	read.Coins = 42
	H.eq("a read value is a copy: edits to it do not reach the store", store:GetAsync(k2).Coins, 1)

	-- UpdateAsync
	local k3 = uniqueKey("update")
	local result = store:UpdateAsync(k3, function(old: any)
		H.eq("UpdateAsync passes nil for a missing key", old, nil)
		return { N = 1 }
	end)
	H.eq("UpdateAsync returns the new value", result.N, 1)
	store:UpdateAsync(k3, function(old: any)
		return { N = old.N + 1 }
	end)
	H.eq("UpdateAsync sees the previous value", store:GetAsync(k3).N, 2)
	store:UpdateAsync(k3, function(_old: any)
		return nil
	end)
	H.eq("returning nil from UpdateAsync cancels the write", store:GetAsync(k3).N, 2)

	-- Keys
	H.check("an empty key is rejected", fails(function()
		store:GetAsync("")
	end))
	H.check("a key over 50 characters is rejected", fails(function()
		store:GetAsync(string.rep("k", 51))
	end))
	H.check("a key of exactly 50 characters is accepted", not fails(function()
		store:GetAsync(string.rep("k", 50))
	end))

	-- Values that do not serialize
	local bad = uniqueKey("bad")
	H.check("a function value is rejected", fails(function()
		store:SetAsync(bad, { f = function() end })
	end))
	H.check("NaN is rejected", fails(function()
		store:SetAsync(bad, { n = 0 / 0 })
	end))
	H.check("infinity is rejected", fails(function()
		store:SetAsync(bad, { n = math.huge })
	end))
	H.check("a mixed array and dictionary table is rejected", fails(function()
		store:SetAsync(bad, { 1, 2, x = 3 })
	end))
	H.check("an array with a hole is rejected", fails(function()
		store:SetAsync(bad, { [1] = "a", [3] = "c" })
	end))
	local cyclic: any = {}
	cyclic.self = cyclic
	H.check("a table containing itself is rejected", fails(function()
		store:SetAsync(bad, cyclic)
	end))
	H.eq("a rejected write leaves the key unset", (store:GetAsync(bad)), nil)

	-- Remove
	local k4 = uniqueKey("remove")
	store:SetAsync(k4, { A = 1 })
	store:RemoveAsync(k4)
	H.eq("RemoveAsync deletes the key", (store:GetAsync(k4)), nil)
end

function StoreContract.faults(make: () -> any, H: Harness)
	local store = make()

	-- failNext: an injected outage raises, then clears
	store:failNext(2)
	H.check("failNext: the first call fails", fails(function()
		store:GetAsync("a")
	end))
	H.check("failNext: the second call fails", fails(function()
		store:UpdateAsync("a", function()
			return { x = 1 }
		end)
	end))
	H.check("failNext: the third call succeeds", not fails(function()
		store:GetAsync("a")
	end))
	H.eq("a failed UpdateAsync wrote nothing", (store:GetAsync("a")), nil)
	store:failNext(math.huge, "offline")
	local ok, err = pcall(function()
		store:GetAsync("a")
	end)
	H.check("failNext(huge, message) fails with that message", (not ok) and string.find(tostring(err), "offline") ~= nil)
	store:failNext(0)
	H.check("failNext(0) turns failures off", not fails(function()
		store:GetAsync("a")
	end))

	-- throttle: a request budget per window, on a fake clock
	local now = 0
	store:throttle(3, function()
		return now
	end, 60)
	for i = 1, 3 do
		H.check("throttle: call " .. i .. " is within budget", not fails(function()
			store:GetAsync("t")
		end))
	end
	H.check("throttle: the fourth call in the window is dropped", fails(function()
		store:GetAsync("t")
	end))
	now = 61
	H.check("throttle: the budget returns when the window moves on", not fails(function()
		store:GetAsync("t")
	end))
	store:throttle(nil)

	-- interleave: another server writes between our read and our write
	store:SetAsync("race", { Owner = "none", Version = 1 })
	local runs = 0
	local seenOwners = {}
	store:interleave(function(key: string)
		store:SetAsync(key, { Owner = "other-server", Version = 1 })
	end)
	store:UpdateAsync("race", function(old: any)
		runs += 1
		table.insert(seenOwners, old.Owner)
		if old.Owner ~= "none" then
			return nil -- a session lock: someone else holds it, so do not take it
		end
		return { Owner = "me", Version = 1 }
	end)
	H.eq("a conflicting write makes UpdateAsync run the transform again", runs, 2)
	H.eq("the second run sees the other server's value", seenOwners[2], "other-server")
	H.eq("a transform that backs off on conflict leaves the other server's value", store:GetAsync("race").Owner, "other-server")

	-- key info versions advance on every write
	local _, info1 = store:GetAsync("race")
	store:SetAsync("race", { Owner = "x", Version = 1 })
	local _, info2 = store:GetAsync("race")
	H.check("every write gives the key a new Version", info1.Version ~= info2.Version)

	-- value size limit
	store:setMaxValueSize(50)
	H.check("a value over the size limit is rejected", fails(function()
		store:SetAsync("big", { s = string.rep("x", 200) })
	end))
	store:setMaxValueSize(4194304)
end

return StoreContract
