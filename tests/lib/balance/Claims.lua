--!strict
-- Balance claims (framework, game-agnostic): every balance decision or design target is
-- written as a checkable claim about the evaluation results, with the decision it comes
-- from. After a mechanic change, failing claims name the decisions whose evidence moved.
--
-- claim = {
--   id = "DT4",                  -- stable id
--   source = "GDD DT4" | "decision 0015", -- where the decision is recorded
--   text = "solo run lasts 30-45 rounds",
--   value = function(results) -> number?,  -- reads the evaluation results
--   min = number?, max = number?,          -- inclusive range
--   gap = "why"?,  -- a known gap: always reported, never fails the suite
-- }

local Claims = {}

function Claims.evaluate(claims: { any }, results: any): { any }
	local evaluated = {}
	for _, claim in ipairs(claims) do
		local ok, value = pcall(claim.value, results)
		local holds = ok and value ~= nil and (claim.min == nil or value >= claim.min) and (claim.max == nil or value <= claim.max)
		table.insert(evaluated, { claim = claim, value = if ok then value else nil, holds = holds, error = if ok then nil else value })
	end
	return evaluated
end

local function range(claim: any): string
	if claim.min and claim.max then
		return string.format("%g-%g", claim.min, claim.max)
	elseif claim.min then
		return ">= " .. claim.min
	elseif claim.max then
		return "<= " .. claim.max
	end
	return "any"
end

function Claims.line(entry: any): string
	local claim = entry.claim
	local status = if entry.holds then "ok  " elseif claim.gap then "GAP " else "FAIL"
	local value = if entry.error then "error: " .. tostring(entry.error) else tostring(entry.value)
	local text = string.format("%s %-8s %s = %s (want %s) [%s]", status, claim.id, claim.text, value, range(claim), claim.source)
	if claim.gap and not entry.holds then
		text ..= " -- known gap: " .. claim.gap
	end
	return text
end

-- Checks every claim that isn't a known gap with `check(name, ok)` (the test harness),
-- and returns the lines for known gaps, so a suite can always print them.
function Claims.assert(evaluated: { any }, check: (string, boolean) -> ()): { string }
	local gaps = {}
	for _, entry in ipairs(evaluated) do
		if entry.claim.gap and not entry.holds then
			table.insert(gaps, Claims.line(entry))
		else
			check(Claims.line(entry), entry.holds)
		end
	end
	return gaps
end

return Claims
