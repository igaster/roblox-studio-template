--!strict
-- Probe generation for situational balance (framework, game-agnostic). A probe isolates
-- one property of the opposition (armored, fast, clustered, ...) so each option's value
-- can be compared there. Probes come from the game's unit config, so a new property (a
-- resistance, a movement type) adds probes without code changes here.

local Probe = {}

-- units = { [name] = unitConfig }. properties = { {name, has = function(unitConfig, units)
-- -> boolean} }. Returns probes { {name, units = {names...}} } for every property at least
-- one unit has, sorted by name, plus one "all" probe with every unit.
function Probe.fromProperties(units: { [string]: any }, properties: { any }): { any }
	local probes = {}
	for _, property in ipairs(properties) do
		local members = {}
		for name, unit in pairs(units) do
			if property.has(unit, units) then
				table.insert(members, name)
			end
		end
		if #members > 0 then
			table.sort(members)
			table.insert(probes, { name = property.name, units = members })
		end
	end
	table.sort(probes, function(a, b)
		return a.name < b.name
	end)
	local all = {}
	for name in pairs(units) do
		table.insert(all, name)
	end
	table.sort(all)
	table.insert(probes, { name = "all", units = all })
	return probes
end

-- Situational-role check: every option is best in at least one probe, and no option is
-- best in all of them. Returns ok, { optionsWithoutRole }, dominantOption?.
function Probe.roles(bestPerProbe: { [string]: string }, options: { string }): (boolean, { string }, string?)
	local wins, probes = {}, 0
	for _, winner in pairs(bestPerProbe) do
		wins[winner] = (wins[winner] or 0) + 1
		probes += 1
	end
	local missing, dominant = {}, nil
	for _, option in ipairs(options) do
		if not wins[option] then
			table.insert(missing, option)
		elseif wins[option] == probes and probes > 1 then
			dominant = option
		end
	end
	return #missing == 0 and dominant == nil, missing, dominant
end

return Probe
