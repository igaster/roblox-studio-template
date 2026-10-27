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
-- Usage (game code):
--   SessionRecorder.start({ mode = "solo" })
--   SessionRecorder.record("place", { player = "Ann", tower = "Sentry", wave = 3 })
--   SessionRecorder.finish({ lastWave = 21 })
-- Usage (agent, Server datamodel):
--   return SessionRecorder.exportJson()

local HttpService = game:GetService("HttpService")

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

-- Starts a new session (an unfinished previous one is dropped). Returns its id.
function SessionRecorder.start(meta)
	return call("start", meta)
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
