--!strict
-- Recorded play sessions as evidence for tuning (framework, game-agnostic). Runs in Lune and in
-- the engine (Studio maps it to ServerScriptService.Sessions), so a digest can be computed
-- where the recording is, and only the small digest leaves Studio.
--
-- Two kinds of data, one set of functions:
--   * a session: what shared/SessionRecorder holds in memory and exports as JSON (events, with
--     times, kinds and data);
--   * a digest: a few numbers computed from a session by the GAME'S metrics, small enough to
--     pass through MCP, save in the repo (playtests/digests/) and compare later.
--
-- What the framework fixes and what each game decides:
--   fixed    the digest envelope (id, meta, durationSeconds, metrics), the loaders and checks,
--            filtering by meta, stale-config detection, median/compare/diff.
--   the game its metric names and functions (a pure module both Studio and Lune can require),
--            the model's value and the tolerance for each metric, what goes in `meta`, optional
--            per-round `series` and free-form `extra` data in a digest, and which sources it
--            records. Nothing here knows a game's units, rounds or items.
--
-- In Studio, on the Server datamodel (an agent over MCP, or a dev command):
--   local digests = Sessions.digest(SessionRecorder.sessions(true), require(...SessionMetrics).metrics)
--   return HttpService:JSONEncode(digests)               -- hundreds of bytes per session
-- In Lune:
--   local digests = Sessions.loadDigests(fs.readFile("playtests/digests/studio-ab12cd34.json"))
--   local lines = Sessions.compare(digests, { firstBuy = Sessions.metric("firstBuy") }, model, 0.25)
--
-- Recordings show what happened, not why: a mismatch is a question for the player, and a
-- comparison on a handful of sessions only shows gross differences (see the roblox-playtest
-- skill, "Recording sessions" and "Analysing recordings").

local Sessions = {}

export type Event = { t: number, kind: string, data: any }
export type Session = {
	id: string,
	startedAt: string?,
	meta: { [string]: any },
	events: { Event },
	summary: { [string]: any }?,
	durationSeconds: number?,
}
export type Digest = {
	digestSchema: number,
	id: string,
	meta: { [string]: any },
	durationSeconds: number?,
	metrics: { [string]: number },
	series: { [string]: { number } }?,
	extra: any?,
}
export type Stats = { n: number, min: number, median: number, max: number, mean: number }
export type Entry = {
	metric: string,
	n: number, -- sessions that produced a value
	missing: number, -- sessions where the metric didn't apply (extractor returned nil)
	median: number?,
	expected: number?,
	diff: number?, -- relative difference of the median from the expected value
	tolerance: number?,
	ok: boolean?, -- nil when there is nothing to compare
}

Sessions.SUPPORTED_SCHEMA = 1 -- session format (SessionRecorder.SCHEMA)
Sessions.DIGEST_SCHEMA = 1
Sessions.SOURCES = { agent = true, studio = true, live = true }

-- ---- Loading and validating ---------------------------------------------------

local function validateMeta(meta: any, problems: { string })
	if type(meta) ~= "table" then
		table.insert(problems, "missing meta")
		return
	end
	if type(meta.schema) ~= "number" then
		table.insert(problems, "missing meta.schema (recorded before sessions were versioned)")
	elseif meta.schema > Sessions.SUPPORTED_SCHEMA then
		table.insert(problems, "meta.schema " .. meta.schema .. " is newer than this reader supports")
	end
	if not Sessions.SOURCES[meta.source] then
		table.insert(problems, "meta.source must be agent, studio or live (got " .. tostring(meta.source) .. ")")
	end
end

-- Problems with one session (empty list = fine).
function Sessions.validate(session: any): { string }
	local problems = {}
	if type(session) ~= "table" then
		return { "not a table" }
	end
	if type(session.id) ~= "string" then
		table.insert(problems, "missing id")
	end
	validateMeta(session.meta, problems)
	if type(session.events) ~= "table" then
		table.insert(problems, "missing events")
	else
		local last = -math.huge
		for i, event in ipairs(session.events) do
			if type(event.kind) ~= "string" or type(event.t) ~= "number" then
				table.insert(problems, "event " .. i .. " needs a kind and a time")
				break
			end
			if event.t < last then
				table.insert(problems, "event " .. i .. " goes back in time")
				break
			end
			last = event.t
		end
	end
	return problems
end

-- Problems with one digest (empty list = fine).
function Sessions.validateDigest(digest: any): { string }
	local problems = {}
	if type(digest) ~= "table" then
		return { "not a table" }
	end
	if type(digest.digestSchema) ~= "number" then
		table.insert(problems, "missing digestSchema")
	elseif digest.digestSchema > Sessions.DIGEST_SCHEMA then
		table.insert(problems, "digestSchema " .. digest.digestSchema .. " is newer than this reader supports")
	end
	if type(digest.id) ~= "string" then
		table.insert(problems, "missing id")
	end
	validateMeta(digest.meta, problems)
	if type(digest.metrics) ~= "table" then
		table.insert(problems, "missing metrics")
	else
		for name, value in pairs(digest.metrics) do
			if type(value) ~= "number" then
				table.insert(problems, "metric " .. tostring(name) .. " is not a number")
			end
		end
	end
	return problems
end

-- Decodes a JSON array and keeps the items `check` accepts. Returns them and one line per
-- rejected item, so a bad file is reported, not silently ignored.
local function loadAll(json: string, check: (any) -> { string }): ({ any }, { string })
	local serde = require("@lune/serde") -- Lune only: loading files is not done in Studio
	local ok, decoded = pcall(serde.decode, "json" :: any, json)
	if not ok or type(decoded) ~= "table" then
		return {}, { "not JSON: " .. tostring(decoded) }
	end
	local kept, problems = {}, {}
	for index, item in ipairs(decoded) do
		local why = check(item)
		if #why == 0 then
			table.insert(kept, item)
		else
			local id = if type(item) == "table" and item.id then item.id else "#" .. index
			table.insert(problems, id .. ": " .. table.concat(why, "; "))
		end
	end
	return kept, problems
end

-- A JSON array of sessions (SessionRecorder.exportJson): the valid ones, and the rejects.
function Sessions.load(json: string): ({ Session }, { string })
	return loadAll(json, Sessions.validate)
end

-- A JSON array of digests (saved from Sessions.digest): the valid ones, and the rejects.
function Sessions.loadDigests(json: string): ({ Digest }, { string })
	return loadAll(json, Sessions.validateDigest)
end

-- ---- Selecting (works on sessions and digests: both have `meta`) --------------------

-- Items whose meta matches every key in `where`. A value may be a list of allowed values:
-- Sessions.filter(items, { source = { "agent", "studio" }, stage = "Foundry" }).
function Sessions.filter<T>(items: { T }, where: { [string]: any }): { T }
	local kept = {}
	for _, item in ipairs(items) do
		local meta = (item :: any).meta
		local matches = true
		for key, wanted in pairs(where) do
			local actual = meta[key]
			if type(wanted) == "table" then
				matches = matches and table.find(wanted, actual) ~= nil
			else
				matches = matches and actual == wanted
			end
		end
		if matches then
			table.insert(kept, item)
		end
	end
	return kept
end

-- Splits items into those played under `stamp` (the current config) and the rest (stale or
-- unstamped). Only the first group is evidence about the current numbers.
function Sessions.byStamp<T>(items: { T }, stamp: string): ({ T }, { T })
	local current, stale = {}, {}
	for _, item in ipairs(items) do
		table.insert(if (item :: any).meta.configStamp == stamp then current else stale, item)
	end
	return current, stale
end

-- ---- Reading one session -----------------------------------------------------------

local function matching(session: Session, kind: string, pred: ((any) -> boolean)?): { Event }
	local found = {}
	for _, event in ipairs(session.events) do
		if event.kind == kind and (pred == nil or pred(event.data)) then
			table.insert(found, event)
		end
	end
	return found
end

-- The events of one kind, in order, optionally filtered by `pred(data)`. A game's replay
-- adapter turns these decisions into a scripted persona.
function Sessions.events(session: Session, kind: string, pred: ((any) -> boolean)?): { Event }
	return matching(session, kind, pred)
end

function Sessions.count(session: Session, kind: string, pred: ((any) -> boolean)?): number
	return #matching(session, kind, pred)
end

-- Seconds into the session of the first matching event, or nil.
function Sessions.firstTime(session: Session, kind: string, pred: ((any) -> boolean)?): number?
	local found = matching(session, kind, pred)
	return if found[1] then found[1].t else nil
end

-- A number from the summary the game gave `finish`, or nil.
function Sessions.summary(session: Session, field: string): number?
	local value = if session.summary then session.summary[field] else nil
	return if type(value) == "number" then value else nil
end

-- ---- Digests --------------------------------------------------------------------------

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Computes a digest per session with the game's metrics: { name = function(session) -> number? }.
-- A metric that returns nil (or a non-finite number) is left out of that digest's `metrics`.
-- `options` (all optional, all the game's own):
--   series  { name = function(session) -> { number }? }  per-round arrays, so a later question
--           about "how did round 7 go" can still be answered from the digest
--   extra   function(session) -> plain table              anything else worth keeping (a short
--           list of key decisions, a stage name ...)
-- The digest keeps the session's full `meta` (source, stamp, stage ...), so filter and byStamp
-- work on digests exactly as on sessions. Plain data only: it is meant to be JSON-encoded.
function Sessions.digest(
	sessions: { Session },
	metrics: { [string]: (Session) -> number? },
	options: { series: { [string]: (Session) -> { number }? }?, extra: ((Session) -> any)? }?
): { Digest }
	local opts = options or {}
	local digests = {}
	for _, session in ipairs(sessions) do
		local values = {}
		for name, compute in pairs(metrics) do
			local value = compute(session)
			if finite(value) then
				values[name] = value
			end
		end
		local digest: Digest = {
			digestSchema = Sessions.DIGEST_SCHEMA,
			id = session.id,
			meta = table.clone(session.meta),
			durationSeconds = session.durationSeconds,
			metrics = values,
		}
		if opts.series then
			local all = {}
			for name, compute in pairs(opts.series) do
				local list = compute(session)
				if list then
					all[name] = list
				end
			end
			digest.series = all
		end
		if opts.extra then
			digest.extra = opts.extra(session)
		end
		table.insert(digests, digest)
	end
	return digests
end

-- A metric extractor that reads a digest: Sessions.compare(digests, { firstBuy = Sessions.metric("firstBuy") }, ...).
function Sessions.metric(name: string): (any) -> number?
	return function(digest: any): number?
		local value = if digest.metrics then digest.metrics[name] else nil
		return if type(value) == "number" then value else nil
	end
end

-- ---- Statistics and comparison -------------------------------------------------------

function Sessions.stats(values: { number }): Stats?
	if #values == 0 then
		return nil
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	local n, sum = #sorted, 0
	for _, v in ipairs(sorted) do
		sum += v
	end
	local median = if n % 2 == 1 then sorted[(n + 1) // 2] else (sorted[n // 2] + sorted[n // 2 + 1]) / 2
	return { n = n, min = sorted[1], median = median, max = sorted[n], mean = sum / n }
end

-- Statistics of `extract(item)` over sessions or digests, skipping those where it returns nil.
-- Also returns how many were skipped.
function Sessions.collect(items: { any }, extract: (any) -> number?): (Stats?, number)
	local values, skipped = {}, 0
	for _, item in ipairs(items) do
		local value = extract(item)
		if value == nil then
			skipped += 1
		else
			table.insert(values, value)
		end
	end
	return Sessions.stats(values), skipped
end

-- Does `measured` agree with `expected` within a relative `tolerance` (0.2 = 20 %)? Also returns
-- the relative difference. An expected value of 0 compares absolutely.
function Sessions.agree(measured: number, expected: number, tolerance: number): (boolean, number)
	local diff = if expected == 0 then math.abs(measured) else math.abs(measured - expected) / math.abs(expected)
	return diff <= tolerance, diff
end

-- Compares each metric's median over `items` (sessions, or digests with Sessions.metric) with
-- the model's value for it.
--   metrics   { name = function(item) -> number? }
--   model     { name = number }       what the simulation or model says
--   tolerance a fraction for all metrics, or { name = fraction }; default 0.25
-- A metric with no model value, or no item that produced it, has ok = nil: reported, never
-- passed or failed.
function Sessions.compare(items: { any }, metrics: { [string]: (any) -> number? }, model: { [string]: number }, tolerance: any): { Entry }
	local names = {}
	for name in pairs(metrics) do
		table.insert(names, name)
	end
	table.sort(names)
	local entries = {}
	for _, name in ipairs(names) do
		local stats, missing = Sessions.collect(items, metrics[name])
		local tol = if type(tolerance) == "table" then tolerance[name] else tolerance
		tol = tol or 0.25
		local expected = model[name]
		local entry: Entry = { metric = name, n = if stats then stats.n else 0, missing = missing, tolerance = tol }
		if stats then
			entry.median = stats.median
		end
		if stats and expected ~= nil then
			entry.expected = expected
			entry.ok, entry.diff = Sessions.agree(stats.median, expected, tol)
		end
		table.insert(entries, entry)
	end
	return entries
end

function Sessions.line(entry: Entry): string
	local status = if entry.ok == nil then "n/a " elseif entry.ok then "ok  " else "DIFF"
	local median = if entry.median then string.format("%g", entry.median) else "-"
	local expected = if entry.expected then string.format("%g", entry.expected) else "-"
	local diff = if entry.diff then string.format("%.0f%%", entry.diff * 100) else "-"
	return string.format(
		"%s %-14s sessions %d (skipped %d)  median %s  model %s  off by %s (tolerance %.0f%%)",
		status,
		entry.metric,
		entry.n,
		entry.missing,
		median,
		expected,
		diff,
		(entry.tolerance or 0) * 100
	)
end

-- ---- Comparing two sets of digests (before and after a retune, or two stamps) -----------

export type Change = { metric: string, nBefore: number, nAfter: number, before: number?, after: number?, change: number? }

-- The median of every metric present in either set, before against after. `change` is the
-- relative change (after - before) / |before|, or nil when there is no before value (or it is
-- 0: then the absolute difference is `after - before`). Sorted by metric name.
function Sessions.diffDigests(before: { Digest }, after: { Digest }): { Change }
	local names, seen = {}, {}
	for _, set in ipairs({ before, after }) do
		for _, digest in ipairs(set) do
			for name in pairs(digest.metrics) do
				if not seen[name] then
					seen[name] = true
					table.insert(names, name)
				end
			end
		end
	end
	table.sort(names)
	local changes = {}
	for _, name in ipairs(names) do
		local statsBefore = Sessions.collect(before, Sessions.metric(name))
		local statsAfter = Sessions.collect(after, Sessions.metric(name))
		local entry: Change = {
			metric = name,
			nBefore = if statsBefore then statsBefore.n else 0,
			nAfter = if statsAfter then statsAfter.n else 0,
			before = if statsBefore then statsBefore.median else nil,
			after = if statsAfter then statsAfter.median else nil,
		}
		if entry.before ~= nil and entry.after ~= nil then
			entry.change = if entry.before == 0 then entry.after - entry.before else (entry.after - entry.before) / math.abs(entry.before)
		end
		table.insert(changes, entry)
	end
	return changes
end

function Sessions.changeLine(entry: Change): string
	local before = if entry.before then string.format("%g", entry.before) else "-"
	local after = if entry.after then string.format("%g", entry.after) else "-"
	local change = if entry.change then string.format("%+.0f%%", entry.change * 100) else "-"
	return string.format("%-14s before %s (n=%d)  after %s (n=%d)  change %s", entry.metric, before, entry.nBefore, after, entry.nAfter, change)
end

return Sessions
