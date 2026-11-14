-- shared/SessionRecorder.lua
--
-- Records play sessions for later analysis: the player's decisions and a few
-- milestones, not logs. A session runs from a match start to its game over. The newest
-- MAX_SESSIONS finished sessions stay in server memory until the server stops, and an
-- agent exports them as JSON over MCP (see the roblox-playtest skill, "Recording
-- sessions"), saving them into the repo.
--
-- Server-side, shared across require caches through ServerBridge, so MCP's
-- execute_luau sees the game's sessions. Overhead: one table insert per recorded event.
--
-- Every session's `meta` carries, besides what the game passes:
--   schema       the format version (SessionRecorder.SCHEMA), so a reader can refuse old files
--   source       who played: "agent" (a scripted or MCP-driven run), "studio" (a human in Studio)
--                or "live" (a real player on a published server). Taken from `meta.source`, else
--                from the workspace attribute `PlaytestSource` (an agent sets it before a run),
--                else "studio" in Studio and "live" elsewhere
--   configStamp  the fingerprint of the game's config (set once with setConfig), so analysis can
--                tell sessions played under an older config from current ones
-- The reader and the comparison with a simulation are tests/lib/balance/Sessions.lua.
--
-- Usage (game code):
--   SessionRecorder.setConfig(GameConfig)          -- once, at startup
--   SessionRecorder.start({ mode = "solo" })
--   SessionRecorder.record("buy", { player = "Ann", item = "Sword", round = 3 })
--   SessionRecorder.finish({ lastRound = 21 })
-- Usage (agent, Server datamodel):
--   return SessionRecorder.exportJson()

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ServerBridge = require(script.Parent.ServerBridge)

local SessionRecorder = {}

local MAX_SESSIONS = 20
local MAX_EVENTS_PER_SESSION = 5000 -- guards memory if something records in a loop

local finished = {} -- oldest first
local current = nil
local startClock = 0
local counter = 0

local function start(meta)
	counter += 1
	startClock = os.clock()
	current = {
		id = string.format("%s-%03d", DateTime.now():FormatUniversalTime("YYYYMMDD-HHmmss", "en-us"), counter),
		startedAt = DateTime.now():ToIsoDate(),
		meta = meta or {},
		events = {},
	}
	return current.id
end

local function record(kind, data)
	if not current or #current.events >= MAX_EVENTS_PER_SESSION then
		return
	end
	table.insert(current.events, { t = math.floor((os.clock() - startClock) * 10) / 10, kind = kind, data = data })
end

local function finish(summary)
	if not current then
		return
	end
	current.summary = summary or {}
	current.durationSeconds = math.floor(os.clock() - startClock)
	table.insert(finished, current)
	if #finished > MAX_SESSIONS then
		table.remove(finished, 1)
	end
	current = nil
end

local function list(includeCurrent)
	local result = table.clone(finished)
	if includeCurrent and current then
		table.insert(result, current)
	end
	return result
end

local call = ServerBridge.connect("SessionRecorderBridge", { start = start, record = record, finish = finish, list = list })

SessionRecorder.SCHEMA = 1

local configStamp: string? = nil

-- Fingerprints the game's config (its plain-value GameConfig) so every session started after
-- this carries the stamp. Call once at startup. Returns the stamp.
function SessionRecorder.setConfig(config)
	local ConfigStamp = require(script.Parent.ConfigStamp)
	configStamp = ConfigStamp.of(config)
	return configStamp
end

local function defaultSource(): string
	local fromAttribute = workspace:GetAttribute("PlaytestSource")
	if type(fromAttribute) == "string" and fromAttribute ~= "" then
		return fromAttribute
	end
	return if RunService:IsStudio() then "studio" else "live"
end

-- Starts a new session (an unfinished previous one is dropped). Returns its id.
-- `meta` is the game's own description of the run (mode, stage, difficulty ...); the recorder
-- adds `schema`, `source` and `configStamp` unless the game already set them.
function SessionRecorder.start(meta)
	local full = table.clone(meta or {})
	full.schema = full.schema or SessionRecorder.SCHEMA
	full.source = full.source or defaultSource()
	full.configStamp = full.configStamp or configStamp
	return call("start", full)
end

-- Records one event in the current session. `data` must be plain JSON-able data.
function SessionRecorder.record(kind, data)
	call("record", kind, data)
end

-- Ends the current session with a summary and keeps it (newest MAX_SESSIONS).
function SessionRecorder.finish(summary)
	call("finish", summary)
end

-- Finished sessions (oldest first), plus the one in progress if `includeCurrent`.
function SessionRecorder.sessions(includeCurrent)
	return call("list", includeCurrent)
end

function SessionRecorder.exportJson(includeCurrent)
	return HttpService:JSONEncode(SessionRecorder.sessions(includeCurrent))
end

return SessionRecorder
