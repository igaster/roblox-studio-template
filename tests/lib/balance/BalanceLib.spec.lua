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

	-- ConfigStamp: the fingerprint a recorded session carries.
	local ConfigStamp = require("../../../src/shared/ConfigStamp")
	local config = { Speed = 4, Name = "x", Waves = { 1, 2, 3 }, Nested = { B = 2, A = 1 } }
	local stamp = ConfigStamp.of(config)
	t.check("ConfigStamp: 8 hex digits", #stamp == 8 and string.match(stamp, "^%x+$") ~= nil)
	t.eq("ConfigStamp: the same config gives the same stamp", ConfigStamp.of({ Nested = { A = 1, B = 2 }, Waves = { 1, 2, 3 }, Name = "x", Speed = 4 }), stamp)
	t.check("ConfigStamp: a changed number changes the stamp", ConfigStamp.of({ Speed = 5, Name = "x", Waves = { 1, 2, 3 }, Nested = { B = 2, A = 1 } }) ~= stamp)
	t.check("ConfigStamp: a changed array item changes the stamp", ConfigStamp.of({ Speed = 4, Name = "x", Waves = { 1, 2, 4 }, Nested = { B = 2, A = 1 } }) ~= stamp)
	t.eq("ConfigStamp: functions are ignored", ConfigStamp.of({ Speed = 4, Name = "x", Waves = { 1, 2, 3 }, Nested = { B = 2, A = 1 }, f = function() end }), stamp)

	-- Sessions: recorded play as evidence.
	local Sessions = require("../../../src/framework/Sessions")
	local function session(id: string, source: string, stampValue: string?, buyAt: number?, lastRound: number?)
		local events = { { t = 1, kind = "start", data = {} } }
		if buyAt then
			table.insert(events, { t = buyAt, kind = "buy", data = { item = "Sword" } })
		end
		return {
			id = id,
			meta = { schema = 1, source = source, configStamp = stampValue, stage = "A" },
			events = events,
			summary = if lastRound then { lastRound = lastRound } else {},
		}
	end
	t.eq("Sessions.validate: a good session has no problems", #Sessions.validate(session("s1", "studio", "abc", 10, 8)), 0)
	t.check("Sessions.validate: an unknown source is a problem", #Sessions.validate(session("s2", "robot", "abc")) == 1)
	local old = session("s3", "agent", "abc")
	old.meta.schema = nil
	t.check("Sessions.validate: a session recorded before versioning is a problem", #Sessions.validate(old) == 1)
	local backwards = session("s4", "agent", "abc", 10)
	table.insert(backwards.events, { t = 2, kind = "buy", data = {} })
	t.check("Sessions.validate: events that go back in time are a problem", #Sessions.validate(backwards) == 1)

	local json = '[{"id":"a","meta":{"schema":1,"source":"agent","configStamp":"abc"},"events":[{"t":1,"kind":"buy","data":{}}],"summary":{"lastRound":9}},{"id":"b","meta":{"source":"x"},"events":[]}]'
	local loaded, problems = Sessions.load(json)
	t.check("Sessions.load: valid sessions are kept, bad ones reported", #loaded == 1 and loaded[1].id == "a" and #problems == 1 and string.find(problems[1], "b:", 1, true) == 1)
	local _, notJson = Sessions.load("{nope")
	t.check("Sessions.load: a file that is not JSON is reported", #notJson == 1)

	local all = {
		session("h1", "studio", "abc", 40, 12),
		session("h2", "studio", "abc", 50, 14),
		session("h3", "studio", "abc", 60, 16),
		session("a1", "agent", "abc", 30, 20),
		session("old", "studio", "zzz", 90, 5),
		session("none", "studio", nil, nil, nil),
	}
	local current, stale = Sessions.byStamp(all, "abc")
	t.check("Sessions.byStamp: other and missing stamps are stale", #current == 4 and #stale == 2)
	t.eq("Sessions.filter: by source", #Sessions.filter(current, { source = "studio" }), 3)
	t.eq("Sessions.filter: a list of allowed values", #Sessions.filter(current, { source = { "studio", "agent" } }), 4)
	t.eq("Sessions.filter: every key must match", #Sessions.filter(current, { source = "agent", stage = "B" }), 0)
	t.eq("Sessions.firstTime", Sessions.firstTime(all[1], "buy"), 40)
	t.eq("Sessions.firstTime: nil when the event never happens", Sessions.firstTime(all[6], "buy"), nil)
	t.eq("Sessions.count: with a predicate", Sessions.count(all[1], "buy", function(d) return d.item == "Sword" end), 1)
	t.eq("Sessions.events: the decisions in order", #Sessions.events(all[1], "buy"), 1)
	t.eq("Sessions.summary", Sessions.summary(all[2], "lastRound"), 14)

	local stats = Sessions.stats({ 5, 1, 3, 9 })
	t.check("Sessions.stats: median of an even count is the middle pair's mean", stats ~= nil and stats.median == 4 and stats.min == 1 and stats.max == 9 and stats.n == 4)
	t.eq("Sessions.stats: nothing gives nil", Sessions.stats({}), nil)
	local humanStats, skipped = Sessions.collect(Sessions.filter(all, { source = "studio" }), function(s) return Sessions.summary(s, "lastRound") end)
	t.check("Sessions.collect: sessions without the metric are skipped and counted", humanStats ~= nil and humanStats.n == 4 and skipped == 1)
	t.check("Sessions.agree: within tolerance", (Sessions.agree(110, 100, 0.15)))
	t.check("Sessions.agree: outside tolerance", not (Sessions.agree(130, 100, 0.15)))

	local entries = Sessions.compare(Sessions.filter(current, { source = "studio" }), {
		firstBuy = function(s) return Sessions.firstTime(s, "buy") end,
		lastRound = function(s) return Sessions.summary(s, "lastRound") end,
		unmodelled = function(s) return Sessions.firstTime(s, "buy") end,
	}, { firstBuy = 50, lastRound = 14 * 2 }, { firstBuy = 0.2, lastRound = 0.2 })
	local byName = {}
	for _, entry in ipairs(entries) do
		byName[entry.metric] = entry
	end
	t.check("Sessions.compare: a metric near the model is ok", byName.firstBuy.ok == true and byName.firstBuy.median == 50)
	t.check("Sessions.compare: a metric far from the model is flagged", byName.lastRound.ok == false and byName.lastRound.diff == 0.5)
	t.check("Sessions.compare: a metric the model does not cover is reported, not judged", byName.unmodelled.ok == nil and byName.unmodelled.n == 3)
	t.check("Sessions.line: flags the difference", string.find(Sessions.line(byName.lastRound), "DIFF", 1, true) == 1)

	-- Digests: a few numbers per session, computed where the recording is (Studio) and saved.
	-- The metrics, series and extra data are the game's own; the framework fixes only the envelope.
	local metrics = {
		firstBuy = function(s) return Sessions.firstTime(s, "buy") end,
		lastRound = function(s) return Sessions.summary(s, "lastRound") end,
		broken = function(_s) return 0 / 0 end, -- a non-finite value must be left out
	}
	local digests = Sessions.digest(Sessions.filter(current, { source = "studio" }), metrics, {
		series = { buys = function(s) return { Sessions.count(s, "buy") } end },
		extra = function(s) return { stage = s.meta.stage } end,
	})
	t.eq("Sessions.digest: one digest per session", #digests, 3)
	t.check("Sessions.digest: the envelope", digests[1].digestSchema == Sessions.DIGEST_SCHEMA and digests[1].id == "h1" and digests[1].meta.source == "studio" and digests[1].meta.configStamp == "abc")
	t.check("Sessions.digest: the game's metrics", digests[1].metrics.firstBuy == 40 and digests[1].metrics.lastRound == 12)
	t.eq("Sessions.digest: a non-finite metric is left out", digests[1].metrics.broken, nil)
	t.check("Sessions.digest: the game's own series and extra data are kept", digests[2].series.buys[1] == 1 and digests[2].extra.stage == "A")
	t.check("Sessions.digest: does not alias the session's meta", digests[1].meta ~= current[1].meta)
	t.eq("Sessions.digest: a game with no series or extra gets neither", Sessions.digest({ all[1] }, metrics)[1].series, nil)
	t.eq("Sessions.validateDigest: a computed digest is valid", #Sessions.validateDigest(digests[1]), 0)

	local serde = require("@lune/serde")
	local encoded = serde.encode("json" :: any, digests)
	local reloaded, digestProblems = Sessions.loadDigests(encoded)
	t.check("Sessions.loadDigests: a saved digest file round-trips", #reloaded == 3 and #digestProblems == 0 and reloaded[2].metrics.lastRound == 14)
	local _, badDigest = Sessions.loadDigests('[{"id":"x","meta":{"schema":1,"source":"studio"},"metrics":{"a":"high"}}]')
	t.check("Sessions.loadDigests: a digest without a schema or with a non-number is rejected", #badDigest == 1)
	t.eq("Sessions.filter and byStamp work on digests too", #(Sessions.byStamp(reloaded, "abc")), 3)

	local fromDigests = Sessions.compare(reloaded, { firstBuy = Sessions.metric("firstBuy"), lastRound = Sessions.metric("lastRound") }, { firstBuy = 50, lastRound = 14 }, 0.1)
	t.check("Sessions.compare: digests give the same answer as the sessions", fromDigests[1].median == 50 and fromDigests[1].ok == true and fromDigests[2].ok == true)

	local slower = Sessions.digest({ session("n1", "studio", "def", 80, 12), session("n2", "studio", "def", 100, 14) }, metrics)
	local changes = Sessions.diffDigests(reloaded, slower)
	local changeByName = {}
	for _, c in ipairs(changes) do
		changeByName[c.metric] = c
	end
	t.check("Sessions.diffDigests: relative change of the median between two sets", changeByName.firstBuy.before == 50 and changeByName.firstBuy.after == 90 and math.abs(changeByName.firstBuy.change - 0.8) < 1e-9)
	t.check("Sessions.diffDigests: counts and a smaller change are reported per metric", changeByName.lastRound.before == 14 and changeByName.lastRound.after == 13 and changeByName.lastRound.nAfter == 2 and math.abs(changeByName.lastRound.change - (13 - 14) / 14) < 1e-9)
	t.check("Sessions.diffDigests: a metric in only one set is reported without a change", (function()
		local only = Sessions.diffDigests(reloaded, Sessions.digest({ session("n3", "studio", "def", 70, nil) }, { other = function(_s) return 5 end }))
		local byMetric = {}
		for _, c in ipairs(only) do
			byMetric[c.metric] = c
		end
		return byMetric.other.before == nil and byMetric.other.after == 5 and byMetric.other.change == nil and byMetric.firstBuy.after == nil
	end)())
	t.check("Sessions.changeLine: shows the change", string.find(Sessions.changeLine(changeByName.firstBuy), "+80%", 1, true) ~= nil)
end
