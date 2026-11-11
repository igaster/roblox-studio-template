-- shared/ServiceLoader.lua
--
-- Starts every ModuleScript in a folder in two phases, so services/controllers can
-- depend on each other without caring about load order:
--
--   1. init()  — synchronous setup: create remotes, read config, set attributes.
--                Must not yield. Runs for ALL modules before any start().
--   2. start() — runtime behaviour: connect events, start loops. Each runs in its own
--                thread, so one yielding start() never blocks the others.
--
-- Both functions are optional. Modules run in alphabetical order by full path.
-- Used by ServerScriptService/Main.server.lua (Services/) and
-- StarterPlayerScripts/Main.client.lua (Controllers/).
--
-- On the client it also starts shared/TestAudio, the Studio-only mute for agent test runs.
--
-- Discovery: every ModuleScript in `folder`, searching through nested Folders
-- (Services/Combat/DamageService.lua is found). Children of a ModuleScript are its
-- private submodules (Rojo's Inventory/init.lua + Inventory/Slots.lua), not services.

local ServiceLoader = {}

local function collect(container: Instance, out: { Instance })
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ModuleScript") then
			table.insert(out, child)
		elseif child:IsA("Folder") then
			collect(child, out)
		end
	end
end

-- Returns the modules ServiceLoader.start would run, in run order.
function ServiceLoader.findModules(folder: Instance): { Instance }
	local modules = {}
	collect(folder, modules)
	table.sort(modules, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return modules
end

-- Names used by more than one module (e.g. Services/A/Data and Services/B/Data). start()
-- returns modules by name, so a duplicate hides one of them there.
function ServiceLoader.duplicateNames(modules: { Instance }): { string }
	local seen, dupes = {}, {}
	for _, module in ipairs(modules) do
		if seen[module.Name] == 1 then
			table.insert(dupes, module.Name)
		end
		seen[module.Name] = (seen[module.Name] or 0) + 1
	end
	return dupes
end

-- Run an init(). Returns nil when it finished, or its thread when it yielded (init() must
-- not yield: it delays every other module's init() and all start()s). Errors are rethrown with
-- the module's name and traceback.
function ServiceLoader.beginInit(name: string, init: () -> ()): thread?
	local co = coroutine.create(init)
	local ok, err = coroutine.resume(co)
	if not ok then
		error(string.format("ServiceLoader: %s.init() failed: %s", name, debug.traceback(co, tostring(err))), 0)
	end
	return if coroutine.status(co) == "dead" then nil else co
end

local function requireAll(modules: { Instance })
	local loaded = {}
	for _, module in ipairs(modules) do
		local ok, result = pcall(require, module)
		if not ok then
			error(string.format("ServiceLoader: failed to require %s: %s", module:GetFullName(), tostring(result)))
		end
		table.insert(loaded, { name = module.Name, value = result })
	end
	return loaded
end

-- Require, init and start every module found by findModules(folder).
-- Returns a name → module table for debugging.
function ServiceLoader.start(folder: Instance): { [string]: any }
	local modules = ServiceLoader.findModules(folder)
	for _, name in ipairs(ServiceLoader.duplicateNames(modules)) do
		warn(string.format("ServiceLoader: more than one module named %q in %s; rename one", name, folder:GetFullName()))
	end
	local loaded = requireAll(modules)
	if game:GetService("RunService"):IsClient() then
		-- Studio-only test mute (TestHooks.muteAudio); does nothing in a published game.
		require(script.Parent.TestAudio).start()
	end

	for _, entry in ipairs(loaded) do
		if type(entry.value) == "table" and type(entry.value.init) == "function" then
			local pending = ServiceLoader.beginInit(entry.name, entry.value.init)
			if pending then
				warn(string.format("ServiceLoader: %s.init() yielded; move waiting code to start()", entry.name))
				-- Keep the two-phase order: nothing else starts until this init() finishes.
				while coroutine.status(pending) ~= "dead" do
					task.wait()
				end
			end
		end
	end

	local byName = {}
	for _, entry in ipairs(loaded) do
		byName[entry.name] = entry.value
		if type(entry.value) == "table" and type(entry.value.start) == "function" then
			task.spawn(entry.value.start)
		end
	end
	return byName
end

return ServiceLoader
