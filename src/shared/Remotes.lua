-- shared/Remotes.lua
--
-- Single access point for RemoteEvents/RemoteFunctions, all kept in
-- ReplicatedStorage.Remotes. The server creates them; clients wait for them.
--
--   Server, in a service's init():   local buy = Remotes.event("RequestUpgrade")
--   Client, in a controller's start(): Remotes.event("RequestUpgrade"):FireServer(tier)
--
-- Rules (CLAUDE.md "Networking"):
--   * Create remotes on the server in init(), so they exist before any client asks.
--   * Name remotes after the player's intent ("RequestUpgrade"), not the effect.
--   * The server validates every argument (typeof checks, ranges, ownership) and
--     never trusts client-sent values for state it owns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"
local CLIENT_TIMEOUT_SECONDS = 10

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end

	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_TIMEOUT_SECONDS)
	if not folder then
		error("Remotes: ReplicatedStorage.Remotes missing. Is ServerScriptService/Main.server.lua running?")
	end
	return folder
end

local function getRemote(name: string, className: string): Instance
	local folder = getFolder()

	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			if not existing:IsA(className) then
				error(string.format("Remotes: %q already exists as %s, not %s", name, existing.ClassName, className))
			end
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end

	local remote = folder:WaitForChild(name, CLIENT_TIMEOUT_SECONDS)
	if not remote then
		error(string.format("Remotes: %q not found after %ds. Create it in a server service's init().", name, CLIENT_TIMEOUT_SECONDS))
	end
	return remote
end

function Remotes.event(name: string): RemoteEvent
	return getRemote(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return getRemote(name, "RemoteFunction") :: RemoteFunction
end

return Remotes
