-- Parallel evaluation runs (framework, game-agnostic): runs jobs in separate Lune
-- processes, up to `limit` at once, so a scenario matrix uses every core.
--
-- Parallel.lune(worker, jobs, limit, cost?) runs `lune run <worker> <job as JSON>` per job.
-- The worker prints its result as JSON on the last line of stdout. Returns the decoded
-- results in job order. A failing worker raises an error with its stderr. With `cost(job)`
-- the most expensive jobs start first, so one long job doesn't finish last alone.
-- (Batching several jobs per process was tried and was slower: uneven batches.)

local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local Parallel = {}

-- Logical cores, for a default limit (falls back to 4).
function Parallel.cores()
	local ok, result = pcall(process.exec, "sysctl", { "-n", "hw.ncpu" })
	if ok and result.ok then
		return tonumber((result.stdout:gsub("%s", ""))) or 4
	end
	ok, result = pcall(process.exec, "nproc", {})
	if ok and result.ok then
		return tonumber((result.stdout:gsub("%s", ""))) or 4
	end
	return 4
end

function Parallel.lune(worker, jobs, limit, cost)
	limit = limit or Parallel.cores()
	local queue = {}
	for i = 1, #jobs do
		queue[i] = i
	end
	if cost then
		table.sort(queue, function(a, b)
			return cost(jobs[a]) > cost(jobs[b])
		end)
	end
	local results, nextJob, running, failure = {}, 1, 0, nil
	local function startNext()
		local index = queue[nextJob]
		nextJob += 1
		running += 1
		task.spawn(function()
			local ok, output = pcall(process.exec, "lune", { "run", worker, serde.encode("json", jobs[index]) })
			if not ok or not output.ok then
				failure = failure or string.format("job %d failed: %s", index, if ok then output.stderr else tostring(output))
			else
				local lastLine = output.stdout:match("([^\n]+)\n*$")
				results[index] = serde.decode("json", lastLine)
			end
			running -= 1
		end)
	end
	while nextJob <= #jobs or running > 0 do
		while running < limit and nextJob <= #jobs do
			startNext()
		end
		task.wait(0.02)
	end
	if failure then
		error(failure, 0)
	end
	return results
end

return Parallel
