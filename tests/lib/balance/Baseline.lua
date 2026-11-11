-- Metric baselines (framework, game-agnostic): save a run of the evaluation as flat
-- numbers in the repo, and diff a new run against it, so a mechanic change shows what
-- moved. Runs under Lune.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Baseline = {}

-- { [scenarioId] = { [metric] = number | nil } } -> { ["scenarioId :: metric"] = number }.
-- Non-numbers are skipped; a missing value (e.g. "never lost") is stored as -1.
function Baseline.flatten(results)
	local flat = {}
	for id, metrics in pairs(results) do
		for metric, value in pairs(metrics) do
			if type(value) == "number" then
				flat[id .. " :: " .. metric] = value
			elseif value == false then
				flat[id .. " :: " .. metric] = -1
			end
		end
	end
	return flat
end

function Baseline.save(path, flat, meta)
	fs.writeFile(path, serde.encode("json", { meta = meta or {}, values = flat }, true))
end

function Baseline.load(path)
	if not fs.isFile(path) then
		return nil
	end
	return serde.decode("json", fs.readFile(path))
end

-- Keys whose value changed by more than `tolerance` (absolute), appeared, or vanished.
-- Returns a sorted list of { key, old, new }.
function Baseline.diff(old, new, tolerance)
	tolerance = tolerance or 0
	local changes, keys = {}, {}
	for key in pairs(old) do
		keys[key] = true
	end
	for key in pairs(new) do
		keys[key] = true
	end
	for key in pairs(keys) do
		local a, b = old[key], new[key]
		if a == nil or b == nil or math.abs(a - b) > tolerance then
			table.insert(changes, { key = key, old = a, new = b })
		end
	end
	table.sort(changes, function(x, y)
		return x.key < y.key
	end)
	return changes
end

return Baseline
