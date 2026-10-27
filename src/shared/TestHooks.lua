-- shared/TestHooks.lua
--
-- Observability / test-harness API, shipped as part of the template so every
-- game gets it for free — no per-game debug code needed. Used by the `critic`
-- agent and any ad-hoc live verification (see the `roblox-playtest` skill for
-- how it's actually driven); also safe to use for your own manual debugging.
--
-- Server-authoritative (CLAUDE.md "Server Authority"): call these from
-- server-side code. Read the results back via execute_luau on the SERVER
-- datamodel — the event buffer lives in this module's server-side instance,
-- not the client's separate copy of the same ModuleScript.
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
local Players = game:GetService("Players")

local ServerBridge = require(script.Parent.ServerBridge)

local TestHooks = {}

local DEFAULT_TAG = "Interactable"
-- Each category keeps its own newest events, so a high-volume category (one event per
-- kill) can't evict rare important ones (player decisions, phase changes).
local MAX_EVENTS_PER_CATEGORY = 300

local eventsByCategory = {} -- [category] = { {time, category, message, data}, ... }, oldest first
local quietCategories = {} -- [category] = true: record but don't print

local function appendEvent(event)
	local list = eventsByCategory[event.category]
	if not list then
		list = {}
		eventsByCategory[event.category] = list
	end
	table.insert(list, event)
	if #list > MAX_EVENTS_PER_CATEGORY then
		table.remove(list, 1)
	end
end

local function filterEvents(sinceTime, category)
	local result = {}
	for name, list in pairs(eventsByCategory) do
		if category == nil or name == category then
			for _, e in ipairs(list) do
				if sinceTime == nil or e.time >= sinceTime then
					table.insert(result, e)
				end
			end
		end
	end
	table.sort(result, function(a, b)
		return a.time < b.time
	end)
	return result
end

-- MCP's execute_luau has its own copy of this module; the bridge makes every copy share
-- the game's event log (see ServerBridge).
local call = ServerBridge.connect("TestHooksBridge", { log = appendEvent, get = filterEvents })

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
function TestHooks.log(category, message, data)
	local event = {
		time = os.clock(),
		category = category,
		message = message,
		data = data,
	}
	call("log", event)
	if quietCategories[category] then
		return
	end
	print(string.format("[TestHooks:%s] %s", category, message))
end

-- Stop printing a high-volume category (e.g. one event per enemy kill) while still
-- recording it for getEvents(). Applies to logs made through this module copy, i.e.
-- call it from the game code that does the logging.
function TestHooks.setQuiet(category, quiet)
	quietCategories[category] = quiet ~= false or nil
end

-- Return recorded events at or after sinceTime (an os.clock() value from an
-- earlier TestHooks call or sample), optionally filtered to one category.
-- Omit both args for the full buffer.
function TestHooks.getEvents(sinceTime, category)
	return call("get", sinceTime, category)
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

return TestHooks
