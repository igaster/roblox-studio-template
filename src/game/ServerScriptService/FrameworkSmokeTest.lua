-- In-engine checks for the framework's own shared modules (not the game). ModuleScript, never
-- auto-runs. Run it in a fresh Play session, on the Server datamodel, via the Studio MCP:
--
--   return require(game.ServerScriptService.FrameworkSmokeTest).run()
--
-- (Not in edit mode: there require() caches modules for the whole session, so after a Rojo
-- sync it can run old versions of this test or of the modules it checks.)
--
-- Prints per-check PASS/FAIL and FRAMEWORK SMOKE OK / FRAMEWORK SMOKE FAILED.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FrameworkSmokeTest = {}

-- A second, independent copy of TestHooks, as a separate execution context would get it.
local function freshTestHooks()
	local holder = Instance.new("Folder")
	holder.Name = "FrameworkSmokeTestScratch"
	holder.Parent = ServerStorage
	local copy = ReplicatedStorage.Shared.TestHooks:Clone()
	copy.Parent = holder
	return require(copy), holder
end

function FrameworkSmokeTest.run(): boolean
	local passed, failed = 0, 0
	local function check(name: string, cond: boolean)
		if cond then
			passed += 1
			print("  PASS: " .. name)
		else
			failed += 1
			warn("  FAIL: " .. name)
		end
	end

	print("=== framework smoke test ===")
	-- Two fresh copies: require() caches per session in edit mode, so the shared
	-- ReplicatedStorage.Shared.TestHooks may still be an older version here.
	local TestHooks, holderA = freshTestHooks()
	local other, holder = freshTestHooks()

	local store = ServerStorage:FindFirstChild("TestHooksEvents")
	local firstSeq = store and store:GetAttribute("NextSeq") or 1

	local marker = "smoke-" .. tostring(os.clock())
	TestHooks.log("FrameworkSmoke", marker)
	local seen = false
	for _, e in ipairs(other.getEvents(nil, "FrameworkSmoke")) do
		if e.message == marker then
			seen = true
		end
	end
	check("cross-copy events: a fresh module copy reads logged events", seen)

	-- A full store, logged quietly (setQuiet: recorded, not printed).
	TestHooks.setQuiet("FrameworkSmokeBulk")
	local tBulk = os.clock()
	for i = 1, TestHooks.MAX_EVENTS + 10 do
		TestHooks.log("FrameworkSmokeBulk", "bulk " .. i)
	end
	local logSeconds = os.clock() - tBulk
	local tRead = os.clock()
	local all = TestHooks.getEvents()
	local readSeconds = os.clock() - tRead
	print(string.format("  (full store: %d logs took %.2f s, one getEvents %.3f s)", TestHooks.MAX_EVENTS + 10, logSeconds, readSeconds))
	local bulk = TestHooks.getEvents(nil, "FrameworkSmokeBulk")
	check("bounded: at most MAX_EVENTS kept", #all <= TestHooks.MAX_EVENTS)
	check("bounded: oldest events dropped first", bulk[1] ~= nil and bulk[1].message ~= "bulk 1")
	check("setQuiet: quiet events are still recorded", #bulk > 0)
	TestHooks.setQuiet("FrameworkSmokeBulk", false)

	local part = Instance.new("Part")
	local ok = pcall(TestHooks.log, "FrameworkSmokeData", "non-json", {
		pos = Vector3.new(1, 2, 3),
		part = part,
		fn = function() end,
		nested = { deeper = { value = 5 } },
	})
	part:Destroy()
	check("non-JSON data: log does not error", ok)
	local dataEvents = TestHooks.getEvents(nil, "FrameworkSmokeData")
	local data = dataEvents[#dataEvents] and dataEvents[#dataEvents].data
	check("non-JSON data: Vector3 read back as a string", type(data) == "table" and type(data.pos) == "string")
	check("non-JSON data: plain nested values survive", type(data) == "table" and data.nested.deeper.value == 5)

	TestHooks.log("FrameworkSmokeNoData", "no data")
	TestHooks.log("FrameworkSmokeFalse", "false data", false)
	local noData = TestHooks.getEvents(nil, "FrameworkSmokeNoData")
	local falseData = TestHooks.getEvents(nil, "FrameworkSmokeFalse")
	check("no data: read back as nil", noData[1] ~= nil and noData[1].data == nil)
	check("false data: read back as false", falseData[1] ~= nil and falseData[1].data == false)

	local t = os.clock()
	TestHooks.log("FrameworkSmokeA", "a")
	TestHooks.log("FrameworkSmokeB", "b")
	local onlyA = TestHooks.getEvents(t, "FrameworkSmokeA")
	check("filters: since + category", #onlyA == 1 and onlyA[1].message == "a")

	-- Remove every event this test logged (it must not leave noise for the game's own events).
	store = ServerStorage:FindFirstChild("TestHooksEvents")
	if store then
		for _, child in ipairs(store:GetChildren()) do
			if (tonumber(child.Name) or 0) >= firstSeq then
				child:Destroy()
			end
		end
	end
	check("cleanup: no FrameworkSmoke events left", #TestHooks.getEvents(nil, "FrameworkSmokeA") == 0)

	-- waitForEvent: sees an event logged later by another copy; ignores older ones; times out.
	TestHooks.log("FrameworkSmokeWait", "old")
	local tWait = os.clock()
	task.delay(0.3, function()
		other.log("FrameworkSmokeWait", "new")
	end)
	local got = TestHooks.waitForEvent(tWait, "FrameworkSmokeWait", nil, 3)
	check("waitForEvent: returns the event logged after since", got ~= nil and got.message == "new")
	check("waitForEvent: nil on timeout", TestHooks.waitForEvent(os.clock(), "FrameworkSmokeNever", nil, 0.3) == nil)

	-- muteAudio: sets the attribute every client's TestAudio watches.
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local wasMuted = ReplicatedStorage:GetAttribute(TestHooks.MUTE_ATTRIBUTE)
	other.muteAudio(true)
	check("muteAudio: on", ReplicatedStorage:GetAttribute(TestHooks.MUTE_ATTRIBUTE) == true)
	other.muteAudio(false)
	check("muteAudio: off", ReplicatedStorage:GetAttribute(TestHooks.MUTE_ATTRIBUTE) == false)
	ReplicatedStorage:SetAttribute(TestHooks.MUTE_ATTRIBUTE, wasMuted)

	-- Dev commands: registered in one copy, run from another (as execute_luau would).
	TestHooks.registerCommand("FrameworkSmokeAdd", function(a, b)
		return a + b
	end)
	local okRun, sum = pcall(other.runCommand, "FrameworkSmokeAdd", 2, 3)
	check("commands: run from another copy", okRun and sum == 5)
	TestHooks.registerCommand("FrameworkSmokeAdd", function(a, b)
		return a * b
	end)
	local _, product = pcall(other.runCommand, "FrameworkSmokeAdd", 2, 3)
	check("commands: re-register replaces", product == 6)
	local okUnknown, err = pcall(other.runCommand, "FrameworkSmokeMissing")
	check("commands: unknown name errors with the list", not okUnknown and string.find(tostring(err), "FrameworkSmokeAdd", 1, true) ~= nil)

	-- The attribute route (works when execute_luau is sandboxed): JSON-array arguments.
	local key = TestHooks.DEV_PREFIX .. "FrameworkSmokeAdd"
	ServerStorage:SetAttribute(key .. "_Done", false)
	ServerStorage:SetAttribute(key, "[4, 5]")
	local deadline = os.clock() + 3
	while ServerStorage:GetAttribute(key .. "_Done") ~= true and os.clock() < deadline do
		task.wait()
	end
	check("commands: attribute request runs the handler", ServerStorage:GetAttribute(key .. "_Result") == "20")
	check("commands: attribute request is cleared", ServerStorage:GetAttribute(key) == nil)
	for _, suffix in ipairs({ "_Done", "_Result" }) do
		ServerStorage:SetAttribute(key .. suffix, nil)
	end
	local commands = ServerStorage:FindFirstChild("TestHooksCommands")
	local cmd = commands and commands:FindFirstChild("FrameworkSmokeAdd")
	if cmd then
		cmd:Destroy()
	end

	-- SessionRecorder: a session recorded through one copy is read by another (through
	-- ServerBridge, as execute_luau's copy sees the game's). A bridge left by an earlier
	-- copy (e.g. the running game's) owns the state; this test only adds one session.
	local function freshRecorder()
		local recHolder = Instance.new("Folder")
		recHolder.Name = "FrameworkSmokeRecorder"
		recHolder.Parent = ServerStorage
		ReplicatedStorage.Shared.ServerBridge:Clone().Parent = recHolder
		local copy = ReplicatedStorage.Shared.SessionRecorder:Clone()
		copy.Parent = recHolder
		return require(copy), recHolder
	end
	local bridgeExisted = ServerStorage:FindFirstChild("SessionRecorderBridge") ~= nil
	local recA, recHolderA = freshRecorder()
	local recB, recHolderB = freshRecorder()
	local id = recA.start({ smoke = true })
	recA.record("buy", { item = "Sword" })
	recA.finish({ lastRound = 3 })
	local sessions = recB.sessions(false)
	local last = sessions[#sessions]
	check("sessions: another copy sees the finished session", last ~= nil and last.id == id and #last.events == 1)
	check("sessions: exportJson is JSON", string.sub(recB.exportJson(false), 1, 1) == "[")
	recHolderA:Destroy()
	recHolderB:Destroy()
	local bridge = ServerStorage:FindFirstChild("SessionRecorderBridge")
	if bridge and not bridgeExisted then
		bridge:Destroy()
	end

	-- Greybox helper.
	local Greybox = require(ReplicatedStorage.Shared.Greybox)
	local folder = Greybox.folder("FrameworkSmokeGreybox", ServerStorage)
	local p = Greybox.part("Wall", Vector3.new(4, 2, 1), Vector3.new(0, 5, 0), { R = 255, G = 0, B = 0 }, folder)
	local m = Greybox.marker("Spawn", Vector3.new(1, 2, 3), folder)
	check("greybox: part anchored, sized, coloured", p.Anchored and p.Size == Vector3.new(4, 2, 1) and p.Color == Color3.fromRGB(255, 0, 0))
	check("greybox: marker invisible and non-colliding", m.Transparency == 1 and not m.CanCollide and not m.CanQuery)
	folder:Destroy()

	holder:Destroy()
	holderA:Destroy()
	print(string.format("=== %d passed, %d failed ===", passed, failed))
	print(failed == 0 and "FRAMEWORK SMOKE OK" or "FRAMEWORK SMOKE FAILED")
	return failed == 0
end

return FrameworkSmokeTest
