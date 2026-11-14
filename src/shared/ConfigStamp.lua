--!strict
-- shared/ConfigStamp.lua
--
-- A short, deterministic fingerprint of a game's configuration (the plain-value GameConfig
-- table), so a recorded play session says which numbers it was played under. Compare stamps
-- before comparing sessions with a simulation or with each other: a session played under an
-- older config isn't evidence about the current one.
--
-- Pure and dependency-free: runs under Lune and in the engine and gives the same stamp in both.
-- Keys are sorted, numbers are written with fixed precision, functions and engine values are
-- skipped (GameConfig holds plain values only, see CLAUDE.md).
--
--   ConfigStamp.of(GameConfig)  --> "a3f09c12"

local ConfigStamp = {}

local function write(value: any, out: { string }, depth: number)
	local kind = type(value)
	if kind == "number" then
		table.insert(out, string.format("%.12g", value))
	elseif kind == "string" then
		table.insert(out, string.format("%q", value))
	elseif kind == "boolean" then
		table.insert(out, if value then "true" else "false")
	elseif kind == "table" then
		if depth > 32 then
			table.insert(out, "<deep>")
			return
		end
		local keys = {}
		for k in pairs(value) do
			table.insert(keys, k)
		end
		table.sort(keys, function(a: any, b: any)
			local ta, tb = type(a), type(b)
			if ta ~= tb then
				return ta < tb
			end
			return a < b
		end)
		table.insert(out, "{")
		for _, k in ipairs(keys) do
			local v = value[k]
			if type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then
				table.insert(out, tostring(k))
				table.insert(out, "=")
				write(v, out, depth + 1)
				table.insert(out, ",")
			end
		end
		table.insert(out, "}")
	end
	-- anything else (nil, functions, engine values) is skipped
end

-- The canonical text the stamp is computed from (exposed for debugging a mismatch).
function ConfigStamp.canonical(config: any): string
	local out = {}
	write(config, out, 0)
	return table.concat(out)
end

-- 32-bit FNV-1a over the canonical text, as 8 hex digits.
function ConfigStamp.of(config: any): string
	local text = ConfigStamp.canonical(config)
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
end

return ConfigStamp
