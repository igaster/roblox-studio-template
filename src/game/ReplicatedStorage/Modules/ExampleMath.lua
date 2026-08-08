--!strict
-- Example of a PURE gameplay-logic module: no `game:GetService`, no `Instance.new`,
-- no Roblox datatypes (Vector3/Color3). Because it only touches plain Lua values it
-- can be unit-tested headlessly with Lune (see tests/run.lua) — no Studio required.
--
-- Delete this module (and its tests) once you have real `*Math` modules; it exists
-- only to demonstrate the pattern the Testing section of CLAUDE.md describes.

local ExampleMath = {}

-- Clamp `value` into the inclusive range [min, max].
function ExampleMath.clamp(value: number, min: number, max: number): number
	if value < min then
		return min
	elseif value > max then
		return max
	end
	return value
end

-- Linear interpolation between `a` and `b` by `t` (t is clamped to [0, 1]).
function ExampleMath.lerp(a: number, b: number, t: number): number
	t = ExampleMath.clamp(t, 0, 1)
	return a + (b - a) * t
end

-- Map a 0..1 progress ratio onto a 1..stageCount discrete stage (e.g. growth stages,
-- upgrade tiers). Ratios outside [0, 1] are clamped so callers can't index past the ends.
function ExampleMath.stageForRatio(ratio: number, stageCount: number): number
	ratio = ExampleMath.clamp(ratio, 0, 1)
	local stage = math.floor(ratio * (stageCount - 1)) + 1
	return ExampleMath.clamp(stage, 1, stageCount)
end

return ExampleMath
