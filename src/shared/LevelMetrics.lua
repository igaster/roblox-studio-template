--!strict
-- Pure level-scale rules: the dimensions a level is built from (player size, door and
-- corridor widths, jump reach) and what follows from them (the widest gap a player can clear).
-- A game keeps the numbers in `GameConfig.Metrics`; generators and level checks read them from
-- there instead of guessing sizes. No engine types, so the rules also run under Lune.
-- Synced to ReplicatedStorage.Shared.LevelMetrics.
--
-- Why metrics: game scale isn't real-world scale. A level made from guessed sizes feels too
-- big, and a jump the designer thinks is fair turns out to be impossible. Decide the sizes
-- once, derive the rest.
--
--   local gap = LevelMetrics.maxGap(GameConfig.Metrics)   -- widest gap worth building
--   local doorH = GameConfig.Metrics.DoorHeight

local LevelMetrics = {}

-- Workspace.Gravity's default, studs/s². A game that changes gravity sets Metrics.Gravity.
LevelMetrics.DEFAULT_GRAVITY = 196.2

export type Metrics = {
	PlayerHeight: number, -- standing height of the avatar, studs
	PlayerWidth: number, -- shoulder width, studs
	WalkSpeed: number, -- studs/s
	JumpHeight: number, -- studs a jump rises
	Gravity: number?, -- studs/s², default LevelMetrics.DEFAULT_GRAVITY
	DoorHeight: number, -- clear opening
	DoorWidth: number,
	CorridorWidth: number,
	StepHeight: number, -- tallest step the player walks up without jumping
	SafetyMargin: number, -- fraction of a jump's reach never used by a fair gap (0.25 = 25%)
	GridSize: number, -- studs; generators place and size level pieces in multiples of it
}

local REQUIRED = {
	"PlayerHeight",
	"PlayerWidth",
	"WalkSpeed",
	"JumpHeight",
	"DoorHeight",
	"DoorWidth",
	"CorridorWidth",
	"StepHeight",
	"SafetyMargin",
	"GridSize",
}

local function gravity(m: Metrics): number
	return m.Gravity or LevelMetrics.DEFAULT_GRAVITY
end

-- Seconds in the air for a jump that rises `JumpHeight` and lands at the same height.
function LevelMetrics.airTime(m: Metrics): number
	return 2 * math.sqrt(2 * m.JumpHeight / gravity(m))
end

-- Horizontal distance of a running jump, takeoff to landing, at full walk speed.
function LevelMetrics.jumpDistance(m: Metrics): number
	return m.WalkSpeed * LevelMetrics.airTime(m)
end

-- The widest gap worth building: the running-jump distance minus the safety margin, so a
-- player who isn't perfect still clears it.
function LevelMetrics.maxGap(m: Metrics): number
	return LevelMetrics.jumpDistance(m) * (1 - m.SafetyMargin)
end

-- The tallest ledge worth building for a jump up, with the same margin.
function LevelMetrics.maxLedge(m: Metrics): number
	return m.JumpHeight * (1 - m.SafetyMargin)
end

-- `value` rounded to the nearest multiple of the grid. Code places pieces exactly, so a level
-- built from snapped sizes lines up without a snapping tool.
function LevelMetrics.snap(m: Metrics, value: number): number
	return math.floor(value / m.GridSize + 0.5) * m.GridSize
end

-- Readable problems, empty when the metrics are usable and consistent.
function LevelMetrics.validate(m: any): { string }
	if type(m) ~= "table" then
		return { "GameConfig.Metrics must be a table" }
	end
	local problems: { string } = {}
	for _, key in ipairs(REQUIRED) do
		if type(m[key]) ~= "number" or m[key] < 0 then
			table.insert(problems, "Metrics." .. key .. " must be a non-negative number")
		end
	end
	if m.Gravity ~= nil and (type(m.Gravity) ~= "number" or m.Gravity <= 0) then
		table.insert(problems, "Metrics.Gravity must be a positive number")
	end
	if #problems > 0 then
		return problems -- the relations below need every number
	end
	if m.SafetyMargin >= 1 then
		table.insert(problems, "Metrics.SafetyMargin must be below 1")
	end
	if m.JumpHeight <= 0 or m.WalkSpeed <= 0 or m.GridSize <= 0 then
		table.insert(problems, "Metrics.JumpHeight, WalkSpeed and GridSize must be above 0")
	end
	if m.DoorHeight <= m.PlayerHeight then
		table.insert(problems, "Metrics.DoorHeight must be taller than PlayerHeight")
	end
	if m.DoorWidth <= m.PlayerWidth then
		table.insert(problems, "Metrics.DoorWidth must be wider than PlayerWidth")
	end
	if m.CorridorWidth < m.DoorWidth then
		table.insert(problems, "Metrics.CorridorWidth must be at least DoorWidth")
	end
	if m.StepHeight >= m.JumpHeight then
		table.insert(problems, "Metrics.StepHeight must be below JumpHeight")
	end
	return problems
end

return LevelMetrics
