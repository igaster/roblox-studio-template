-- Framework: pure layout rules used by LayoutCheck (overlaps, on-screen, UI scale).
local LayoutMath = require("../../src/shared/LayoutMath")

return function(t)
	local a = { Name = "A", X = 0, Y = 0, W = 100, H = 40 }
	local b = { Name = "B", X = 100, Y = 0, W = 50, H = 40 }
	local c = { Name = "C", X = 90, Y = 10, W = 50, H = 40 }
	t.check("layout: touching edges don't overlap", not LayoutMath.overlap(a, b))
	t.check("layout: real overlaps are found", LayoutMath.overlap(a, c))
	t.eq("layout: a clean layout has no problems", #LayoutMath.problems({ a, b }, 200, 100), 0)
	t.eq("layout: an overlap and an off-screen element are both reported", #LayoutMath.problems({ a, c }, 120, 100), 2)
	t.eq("layout: allowed pairs are skipped", #LayoutMath.problems({ a, c }, 200, 100, { ["C|A"] = true }), 0)
	t.eq("layout: a wildcard allows any overlap", #LayoutMath.problems({ a, c }, 200, 100, { ["A|*"] = true }), 0)
	t.near("layout: a large window keeps the chosen scale", LayoutMath.uiScale(1.15, 1920, 1080, 960, 540), 1.15)
	t.check("layout: a narrow window shrinks the UI to fit", LayoutMath.uiScale(1, 665, 520, 960, 540) * 960 <= 665)
	t.near("layout: the tighter axis wins", LayoutMath.uiScale(1, 2000, 270, 960, 540), 0.5)
end
