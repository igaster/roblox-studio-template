--!strict
-- Scenario matrices for balance evaluation (framework, game-agnostic). A scenario is a
-- flat table of axis values, e.g. { level = "A", difficulty = "Normal", players = 2 }.
-- The game supplies the axes and a runner; this module only builds and runs the matrix.

local Scenario = {}

-- axes = { {name, values = {...}}, ... } in display order. Returns every combination.
function Scenario.matrix(axes: { { name: string, values: { any } } }): { { [string]: any } }
	local result = { {} }
	for _, axis in ipairs(axes) do
		local next = {}
		for _, partial in ipairs(result) do
			for _, value in ipairs(axis.values) do
				local scenario = table.clone(partial)
				scenario[axis.name] = value
				table.insert(next, scenario)
			end
		end
		result = next
	end
	return result
end

-- A stable id such as "difficulty=Normal level=A players=2" (keys sorted).
function Scenario.id(scenario: { [string]: any }): string
	local keys = {}
	for key in pairs(scenario) do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, key .. "=" .. tostring(scenario[key]))
	end
	return table.concat(parts, " ")
end

-- Runs `runner(scenario) -> metrics table` for each scenario. Returns { [id] = metrics }
-- and the ids in matrix order.
function Scenario.run(scenarios: { { [string]: any } }, runner: (any) -> any): ({ [string]: any }, { string })
	local results, order = {}, {}
	for _, scenario in ipairs(scenarios) do
		local id = Scenario.id(scenario)
		results[id] = runner(scenario)
		table.insert(order, id)
	end
	return results, order
end

return Scenario
