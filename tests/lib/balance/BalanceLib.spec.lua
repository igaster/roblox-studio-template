-- Framework balance toolkit (tests/lib/balance): game-agnostic checks with toy data. Run by tests/framework.lua.
local Scenario = require("./Scenario")
local Metrics = require("./Metrics")
local Probe = require("./Probe")
local Baseline = require("./Baseline")
local Claims = require("./Claims")
local Parallel = require("./Parallel")

return function(t, frameworkRoot: string)
	local matrix = Scenario.matrix({ { name = "level", values = { "A", "B" } }, { name = "players", values = { 1, 2 } } })
	t.eq("Scenario.matrix: every combination", #matrix, 4)
	t.eq("Scenario.id: stable and sorted", Scenario.id({ players = 2, level = "A" }), "level=A players=2")
	local results = Scenario.run(matrix, function(s)
		return { lossRound = if s.level == "A" then 10 else 20 }
	end)
	t.eq("Scenario.run: keyed by id", results["level=B players=1"].lossRound, 20)

	t.eq("Metrics.cliffLength", Metrics.cliffLength({ lossRound = 20, firstTroubleRound = 15 }), 5)
	local rates, total = Metrics.pickRates({ { kind = "place", option = "x" }, { kind = "place", option = "x" }, { kind = "upgrade", option = "y" } }, "place")
	t.check("Metrics.pickRates: share per option", rates.x == 1 and total == 2)
	t.eq("Metrics.ablationLoss", Metrics.ablationLoss({ lossRound = 20 }, { lossRound = 14 }, 100), 6)
	local best = Metrics.bestPerProbe({ armored = { a = 1, b = 3 }, fast = { a = 5, b = 2 } })
	t.check("Metrics.bestPerProbe", best.armored == "b" and best.fast == "a")

	local units = { u1 = { Armor = 5 }, u2 = { Armor = 0, Speed = 20 }, u3 = { Armor = 0, Speed = 5 } }
	local probes = Probe.fromProperties(units, {
		{ name = "armored", has = function(u) return (u.Armor or 0) > 0 end },
		{ name = "flying", has = function(u) return u.Flying == true end },
	})
	t.check("Probe.fromProperties: one probe per present property plus all", #probes == 2 and probes[1].name == "armored" and probes[2].name == "all")
	local ok, missing, dominant = Probe.roles({ armored = "b", fast = "a" }, { "a", "b", "c" })
	t.check("Probe.roles: an option with no probe is reported", not ok and missing[1] == "c" and dominant == nil)
	local _, _, dom = Probe.roles({ armored = "a", fast = "a" }, { "a", "b" })
	t.eq("Probe.roles: a dominant option is reported", dom, "a")

	local flat = Baseline.flatten({ s1 = { lossRound = 10, never = false, name = "x" } })
	t.check("Baseline.flatten: numbers and missing values", flat["s1 :: lossRound"] == 10 and flat["s1 :: never"] == -1 and flat["s1 :: name"] == nil)
	local changes = Baseline.diff({ a = 1, b = 2 }, { a = 1, b = 5, c = 3 }, 0.5)
	t.check("Baseline.diff: changed and new keys", #changes == 2 and changes[1].key == "b" and changes[2].key == "c")

	local evaluated = Claims.evaluate({
		{ id = "T1", source = "test", text = "in range", value = function(r) return r.x end, min = 1, max = 3 },
		{ id = "T2", source = "test", text = "known gap", value = function(r) return r.x end, min = 10, gap = "later" },
	}, { x = 2 })
	local checked = 0
	local gaps = Claims.assert(evaluated, function(_, holds)
		checked += if holds then 1 else 0
	end)
	t.check("Claims: targets are checked, known gaps reported", checked == 1 and #gaps == 1 and gaps[1]:find("known gap") ~= nil)

	local jobs = { { value = 1 }, { value = 2 }, { value = 3 } }
	-- Worker paths are relative to the working directory (the game root), hence the prefix.
	local doubled = Parallel.lune(frameworkRoot .. "/tests/lib/balance/testdata/double.lua", jobs, 2, function(job)
		return job.value
	end)
	t.check("Parallel.lune: results in job order", doubled[1].value == 2 and doubled[2].value == 4 and doubled[3].value == 6)
end
