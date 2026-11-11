-- The only server entry point. Game logic lives in ModuleScripts under
-- ServerScriptService/Services/ (one per system, e.g. PlotService.lua), each
-- exposing optional init() and start(). See shared/ServiceLoader.lua.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceLoader = require(ReplicatedStorage.Shared.ServiceLoader)

ServiceLoader.start(ServerScriptService.Services)
