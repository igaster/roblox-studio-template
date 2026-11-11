-- The only client entry point. UI and input live in ModuleScripts under
-- StarterPlayerScripts/Controllers/ (one per concern, e.g. HudController.lua), each
-- exposing optional init() and start(). See shared/ServiceLoader.lua.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceLoader = require(ReplicatedStorage.Shared.ServiceLoader)

ServiceLoader.start(script.Parent:WaitForChild("Controllers"))
