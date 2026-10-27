-- shared/ServerBridge.lua
--
-- One server-side owner for module state that every copy of the module can reach.
--
-- Code run through MCP's execute_luau gets its OWN copy of every ModuleScript (a
-- separate require cache from the game's scripts), so plain module-level state isn't
-- shared between the running game and an agent inspecting it. connect() makes the first
-- server-side copy the owner of the state and publishes a non-archivable BindableFunction
-- in ServerStorage. Later copies forward every call through it, so all callers see the
-- same state. On the client, or when this copy is the owner, calls run directly.
--
-- Usage:
--   local call = ServerBridge.connect("MyModuleBridge", {
--       add = function(item) table.insert(items, item) end,
--       list = function() return items end,
--   })
--   call("add", 42)
--
-- Values crossing the bridge are copied (no metatables, no functions), so keep the
-- handlers' arguments and results plain data.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ServerBridge = {}

function ServerBridge.connect(name, handlers)
	local function direct(action, ...)
		return handlers[action](...)
	end
	if not RunService:IsServer() then
		return direct
	end
	local existing = ServerStorage:FindFirstChild(name)
	if existing then
		return function(action, ...)
			return existing:Invoke(action, ...)
		end
	end
	local bridge = Instance.new("BindableFunction")
	bridge.Name = name
	bridge.Archivable = false -- never saved into the place file
	bridge.OnInvoke = direct
	bridge.Parent = ServerStorage
	return direct
end

return ServerBridge
