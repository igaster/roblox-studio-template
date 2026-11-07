--!strict
-- Pure screen-layout rules: every visible HUD element is on screen and no two overlap,
-- plus the UI-scale rule that keeps a minimum logical size on small windows.
-- LayoutCheck (Studio-only, client) measures AbsolutePosition/AbsoluteSize and passes the
-- rectangles here, so the rules also run under Lune. Synced to ReplicatedStorage.Shared.

export type Rect = { Name: string, X: number, Y: number, W: number, H: number }

local LayoutMath = {}

-- Overlaps thinner than this (pixels) are rounding, not a real overlap.
local TOLERANCE = 1

function LayoutMath.overlap(a: Rect, b: Rect): boolean
	local w = math.min(a.X + a.W, b.X + b.W) - math.max(a.X, b.X)
	local h = math.min(a.Y + a.H, b.Y + b.H) - math.max(a.Y, b.Y)
	return w > TOLERANCE and h > TOLERANCE
end

function LayoutMath.onScreen(r: Rect, width: number, height: number): boolean
	return r.X >= -TOLERANCE and r.Y >= -TOLERANCE and r.X + r.W <= width + TOLERANCE and r.Y + r.H <= height + TOLERANCE
end

-- The HUD's UIScale: the player's chosen step, shrunk so at least minWidth × minHeight
-- logical pixels fit the window (the layout is designed for that size).
function LayoutMath.uiScale(step: number, width: number, height: number, minWidth: number, minHeight: number): number
	return math.min(step, width / minWidth, height / minHeight)
end

local function isAllowed(ok: { [string]: boolean }, a: string, b: string): boolean
	return ok[a .. "|" .. b] or ok[b .. "|" .. a] or ok[a .. "|*"] or ok[b .. "|*"] or false
end

-- Problems as readable strings, empty when the layout is fine. `allowed` lists pairs that
-- may overlap on purpose ("A|B" with names in either order, or "A|*" for anything), e.g.
-- a modal over the HUD.
function LayoutMath.problems(rects: { Rect }, width: number, height: number, allowed: { [string]: boolean }?): { string }
	local result = {}
	local ok = allowed or {}
	for i, a in ipairs(rects) do
		if not LayoutMath.onScreen(a, width, height) then
			table.insert(result, string.format("%s off screen (%d,%d %dx%d in %dx%d)", a.Name, a.X, a.Y, a.W, a.H, width, height))
		end
		for j = i + 1, #rects do
			local b = rects[j]
			if LayoutMath.overlap(a, b) and not isAllowed(ok, a.Name, b.Name) then
				table.insert(result, string.format("%s overlaps %s", a.Name, b.Name))
			end
		end
	end
	return result
end

return LayoutMath
