--!strict
-- Shared test harness for the headless Lune tests (framework file; games don't edit it).
-- Every test file requires it, so all counts add up into one summary and one exit code:
--
--   local H = require("./harness")
--   H.section("TowerMath")
--   H.eq("cost at level 2", TowerMath.cost(2), 150)
--
-- tests/run.lua loads the test files and calls H.finish(). Each section ends with its count of
-- passed checks, so a section that checked nothing shows "0 passed". Run with --verbose
-- (`make test ARGS=--verbose`) to print every PASS line with its measured value, e.g. to
-- confirm a new check measures something real.

local process = require("@lune/process")

local H = { passed = 0, failed = 0, failures = {} :: { string } }

local verbose = table.find(process.args, "--verbose") ~= nil
local current: string? = nil
local sectionPassed, sectionFailed = 0, 0

local function closeSection()
	if current then
		print(string.format("  %d passed%s", sectionPassed, sectionFailed > 0 and (", " .. sectionFailed .. " failed") or ""))
	end
end

function H.section(title: string)
	closeSection()
	current, sectionPassed, sectionFailed = title, 0, 0
	print(title)
end

function H.check(name: string, cond: any)
	if cond then
		H.passed += 1
		sectionPassed += 1
		if verbose then
			print("  PASS: " .. name)
		end
	else
		H.failed += 1
		sectionFailed += 1
		table.insert(H.failures, name)
		print("  FAIL: " .. name)
	end
end

function H.eq(name: string, actual: any, expected: any)
	H.check(name .. " (got " .. tostring(actual) .. ", want " .. tostring(expected) .. ")", actual == expected)
end

function H.near(name: string, actual: number, expected: number, tol: number?)
	local tolerance = tol or 1e-6
	H.check(
		name .. " (got " .. tostring(actual) .. ", want ~" .. tostring(expected) .. ")",
		math.abs(actual - expected) <= tolerance
	)
end

-- Prints the summary and exits non-zero if anything failed, so it can gate CI.
function H.finish()
	closeSection()
	current = nil
	print(string.format("\n%d passed, %d failed", H.passed, H.failed))
	if H.failed > 0 then
		print("Failing tests:")
		for _, name in ipairs(H.failures) do
			print("  - " .. name)
		end
		process.exit(1)
	end
	print("All tests passed.")
end

return H
