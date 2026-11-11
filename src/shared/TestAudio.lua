-- shared/TestAudio.lua
--
-- Studio-only mute for agent test runs. ServiceLoader starts it on every client. While
-- ReplicatedStorage's TestHooksMuted attribute is true (set by TestHooks.muteAudio on the
-- server), it zeroes every SoundGroup and routes every ungrouped sound (including Roblox's own
-- character sounds) into a silent group. When the attribute is cleared, it puts everything back.
-- Outside Studio it does nothing, so players always hear the game as their settings say.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local TestAudio = {}

local ATTRIBUTE = "TestHooksMuted" -- TestHooks.MUTE_ATTRIBUTE
local silent: SoundGroup? = nil
local savedVolume: { [SoundGroup]: number } = {}
local rerouted: { [Sound]: true } = {}
local connections: { RBXScriptConnection } = {}
local started = false

local function muteGroup(group: SoundGroup)
	if group == silent or savedVolume[group] ~= nil then
		return
	end
	savedVolume[group] = group.Volume
	group.Volume = 0
	-- A settings screen may change the volume while muted: remember it, keep it at 0.
	table.insert(connections, group:GetPropertyChangedSignal("Volume"):Connect(function()
		if group.Volume ~= 0 then
			savedVolume[group] = group.Volume
			group.Volume = 0
		end
	end))
end

local function muteSound(sound: Sound)
	if not sound.SoundGroup and not rerouted[sound] then
		rerouted[sound] = true
		sound.SoundGroup = silent
	end
end

local function visit(d: Instance)
	if d:IsA("Sound") then
		muteSound(d)
	elseif d:IsA("SoundGroup") then
		muteGroup(d)
	end
end

local function watch(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		visit(d)
	end
	table.insert(connections, root.DescendantAdded:Connect(visit))
end

local function mute()
	if silent then
		return
	end
	local group = Instance.new("SoundGroup")
	group.Name = "TestHooksMute"
	group.Volume = 0
	group.Parent = SoundService
	silent = group
	watch(SoundService)
	watch(workspace)
	local player = game:GetService("Players").LocalPlayer
	if player then
		watch(player:WaitForChild("PlayerGui"))
	end
end

local function unmute()
	if not silent then
		return
	end
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	table.clear(connections)
	for group, volume in pairs(savedVolume) do
		if group.Parent then
			group.Volume = volume
		end
	end
	for sound in pairs(rerouted) do
		if sound.Parent and sound.SoundGroup == silent then
			sound.SoundGroup = nil
		end
	end
	table.clear(savedVolume)
	table.clear(rerouted)
	silent:Destroy()
	silent = nil
end

local function apply()
	if ReplicatedStorage:GetAttribute(ATTRIBUTE) == true then
		mute()
	else
		unmute()
	end
end

function TestAudio.start()
	if started or not RunService:IsStudio() then
		return
	end
	started = true
	ReplicatedStorage:GetAttributeChangedSignal(ATTRIBUTE):Connect(apply)
	task.spawn(apply) -- mute() may wait for PlayerGui
end

return TestAudio
