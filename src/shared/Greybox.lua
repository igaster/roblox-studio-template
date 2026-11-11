-- shared/Greybox.lua
--
-- Small building helpers for greybox/prototype level generators (see the
-- `roblox-asset-generators` skill, *Level generators*). Server-side only. Retire with the
-- generator once real art is hand-placed in Studio.
--
--   local Greybox = require(ReplicatedStorage.Shared.Greybox)
--   local room = Greybox.folder("HeistRoom", workspace)
--   Greybox.part("Floor", Vector3.new(60, 1, 60), Vector3.new(0, Greybox.FLOOR_TOP - 0.5, 0),
--       GameConfig.Room.FloorColor, room)

local ConfigTypes = require(script.Parent.ConfigTypes)

local Greybox = {}

-- A Baseplate from Studio's template has its top at Y = 0: floors sit slightly above it so
-- they don't z-fight.
Greybox.FLOOR_TOP = 0.2

-- An anchored, smooth part. `color` is a Color3 or a GameConfig colour table
-- ({ R, G, B }, 0–255); `className` defaults to "Part" (e.g. "WedgePart").
function Greybox.part(name: string, size: Vector3, position: Vector3, color, parent: Instance, className: string?): BasePart
	local p = Instance.new(className or "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = typeof(color) == "Color3" and color or ConfigTypes.color3(color)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Greybox.folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- An invisible, non-colliding, non-queryable part marking a position (spawn points,
-- waypoints, trigger centres).
function Greybox.marker(name: string, position: Vector3, parent: Instance): BasePart
	local p = Greybox.part(name, Vector3.new(1, 1, 1), position, Color3.new(1, 1, 1), parent)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	return p
end

-- The level's player spawn, standing on `floorTop` at `position` (X/Z). Every other
-- SpawnLocation in the workspace is disabled: one left in the place file (Studio's Baseplate
-- template ships one) would otherwise compete, and players would spawn at random between them.
function Greybox.spawn(name: string, position: Vector3, parent: Instance, floorTop: number?): SpawnLocation
	for _, other in ipairs(workspace:GetDescendants()) do
		if other:IsA("SpawnLocation") then
			other.Enabled = false
		end
	end
	local size = Vector3.new(6, 1, 6)
	local s = Instance.new("SpawnLocation")
	s.Name = name
	s.Anchored = true
	s.Size = size
	s.Position = Vector3.new(position.X, (floorTop or Greybox.FLOOR_TOP) + size.Y / 2, position.Z)
	s.Neutral = true
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Parent = parent
	return s
end

return Greybox
