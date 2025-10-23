package.path = table.concat({
	package.path,
	hs.configdir .. "/vendor/?.lua",
	hs.configdir .. "/vendor/?/init.lua",
	hs.configdir .. "/vendor/?/?.lua", -- lets require("inspect") find vendor/inspect/inspect.lua
}, ";")

local inspect = require("inspect")

-- ================================================================================================
-- Auto reload config
-- ================================================================================================

-- Reload config when files change
local function reloadConfig(files)
	local doReload = false
	for _, file in pairs(files) do
		if file:sub(-4) == ".lua" then
			doReload = true
		end
	end

	if doReload then
		-- hs.timer.doAfter(0.5, function()
		hs.reload()
		hs.alert.show("Hammerspoon config loaded")
		-- end)
	end
end
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

hs.alert.show("Hammerspoon config loaded")

-- ================================================================================================
-- Spoons
-- ================================================================================================

-- Caffeine, screen lock:
hs.loadSpoon("Caffeine")
spoon.Caffeine:start()
spoon.Caffeine:setState(true)

-- Clipboard tool: history.
hs.loadSpoon("ClipboardTool")
spoon.ClipboardTool:start()
spoon.ClipboardTool:bindHotkeys({
	show_clipboard = { { "alt" }, "v" },
})
-- disable popup on copy
spoon.ClipboardTool.show_copied_alert = false

-- ================================================================================================
-- Event Hooks
-- ================================================================================================
-- Fix Cmd-Tab to minimized apps: automatically unminimize + focus
hs.window.animationDuration = 0
local okSpaces, spaces = pcall(require, "hs.spaces") -- optional

-- Watch for app activation events, if an app is selected but is hidden or minimized, then unhide/unminimize it (alt tab fix).
appWindowWatcher = hs.application.watcher.new(function(appName, eventType, app)
	if eventType ~= hs.application.watcher.activated then
		return
	end
	app = app or hs.application.get(appName)
	if not app then
		return
	end

	-- If the app was hidden (⌘H), unhide it
	if app:isHidden() then
		app:unhide()
	end

	local wins = app:allWindows()
	-- TODO: if app is not open, maybe we can launch it?
	-- local hasVisible = false
	-- for _, w in ipairs(wins) do
	-- 	if w:isStandard() and w:isVisible() and not w:isMinimized() then
	-- 		hasVisible = true
	-- 		break
	-- 	end
	-- end

	-- -- Ask the app to re-open a window if none are visible
	-- if not hasVisible then
	-- 	app:open()
	-- end

	-- Unminimize anything that’s minimized; optionally move to current Space
	local currentSpace = okSpaces and spaces.focusedSpace() or nil
	for _, w in ipairs(wins) do
		if w:isMinimized() then
			w:unminimize()
			if currentSpace then
				spaces.moveWindowToSpace(w, currentSpace)
			end
		end
	end

	-- Ensure something sensible is focused
	local target = app:mainWindow() or app:focusedWindow() or wins[1]
	if target then
		target:focus()
	end
end)

appWindowWatcher:start()

function contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

-- Screen lock watcher
-- Detects lock/unlock and enable/disable Caffeine accordingly
watcher = hs.caffeinate.watcher.new(function(eventType)
	local activateEvents = {
		hs.caffeinate.watcher.screensDidUnlock,
		hs.caffeinate.watcher.screensDidWake,
		hs.caffeinate.watcher.systemDidWake,
	}
	local deactivateEvents = {
		hs.caffeinate.watcher.screensDidLock,
		hs.caffeinate.watcher.systemWillSleep,
	}
	if contains(activateEvents, eventType) then
		print("Activated Caffeine on event " .. eventType)
		spoon.Caffeine:setState(true)
	elseif contains(deactivateEvents, eventType) then
		print("Deactivated Caffeine on event " .. eventType)
		spoon.Caffeine:setState(false)
	end
end)

watcher:start()

-- ================================================================================================
-- Mac to Linux key binding configuration
-- ================================================================================================

-- Default values for optional fields
local defaultValues = {
	allowModifiers = false, -- allows you to hold other modifiers (like Shift) while remapping
	enabled = true,
	debugHelper = false,
	exceptions = {}, -- list of app bundle IDs to exclude from remapping
	passthrough = false, -- sends the activated keypress as well
}

local terminalApps = {
	"com.apple.Terminal",
	"com.googlecode.iterm2",
	"com.github.wez.wezterm",
}

local browserApps = {
	"com.apple.Safari",
	"com.google.Chrome",
	"org.mozilla.firefox",
}

-- Key binding definitions
local keyBindings = {
	-- source: key to rebind. this is sent to Mac OS. If empty, no events are fired. This is useful to disable a key.
	-- target: key to activate on. `Source` is rebound to `Target`.
	-- description: for debug purposes
	-- exceptions: App to exclude from remapping (by bundle ID), to see bundle ID enter this into Hammerspoon console and alt tab into it:
	--             hs.timer.doAfter(3, function () print(hs.application.frontmostApplication():bundleID()) end)
	--
	-- only: List of Apps (by bundle ID) to only enable this keybinding for.
	-- enabled: keybind ative
	-- passthrough: sends the activated keypress as well
	{
		source = { modifiers = { "cmd" }, key = "c" },
		target = { modifiers = { "ctrl" }, key = "c" },
		description = "Copy",
		exceptions = terminalApps,
		allowModifiers = true,
	},
	{
		source = { modifiers = { "cmd" }, key = "v" },
		target = { modifiers = { "ctrl" }, key = "v" },
		description = "Paste",
		exceptions = terminalApps,
		allowModifiers = true,
	},
	{
		source = { modifiers = { "cmd" }, key = "b" },
		target = { modifiers = { "ctrl" }, key = "b" },
		description = "Bold",
		exceptions = terminalApps,
	},
	{
		source = { modifiers = { "cmd" }, key = "i" },
		target = { modifiers = { "ctrl" }, key = "i" },
		description = "Italic",
		exceptions = terminalApps,
	},
	{
		source = { modifiers = { "cmd" }, key = "x" },
		target = { modifiers = { "ctrl" }, key = "x" },
		description = "Cut",
		exceptions = terminalApps,
	},
	{
		-- collides with ctrl-a which moves cursor to start
		enabled = true,
		source = { modifiers = { "cmd" }, key = "a" },
		target = { modifiers = { "ctrl" }, key = "a" },
		description = "Select All",
		exceptions = terminalApps,
	},
	{
		source = { modifiers = { "cmd" }, key = "z" },
		target = { modifiers = { "ctrl" }, key = "z" },
		description = "Undo",
		exceptions = terminalApps,
	},
	{
		source = { modifiers = { "shift", "cmd" }, key = "z" },
		target = { modifiers = { "shift", "ctrl" }, key = "z" },
		description = "Redo (z key)",
		exceptions = terminalApps,
	},
	{
		source = { modifiers = { "cmd", "shift" }, key = "z" },
		target = { modifiers = { "ctrl" }, key = "y" },
		description = "Redo",
		exceptions = terminalApps,
	},
	{
		source = { modifiers = { "cmd" }, key = "r" },
		target = { modifiers = { "ctrl" }, key = "r" },
		description = "Refresh / Reload",
		exceptions = terminalApps,
		allowModifiers = true,
	},
	{
		source = { modifiers = { "cmd" }, key = "p" },
		target = { modifiers = { "ctrl" }, key = "p" },
		description = "Command Pallette / Print",
		exceptions = terminalApps,
		allowModifiers = true,
	},
	{
		source = { modifiers = { "cmd" }, key = "f" },
		target = { modifiers = { "ctrl" }, key = "f" },
		description = "Find",
		exceptions = terminalApps,
	},
	{
		source = { modifiers = { "cmd" }, key = "left" },
		target = { key = "home" },
		description = "HOME key",
		exceptions = terminalApps,
		allowModifiers = true,
	},
	{
		source = { modifiers = { "cmd" }, key = "right" },
		target = { key = "end" },
		description = "END key",
		exceptions = terminalApps,
		allowModifiers = true,
	},
	{
		source = { modifiers = { "cmd" }, key = "t" },
		target = { modifiers = { "ctrl" }, key = "t" },
		allowModifiers = true,
		only = { "com.google.Chrome", "org.mozilla.firefox" },
		description = "New Tab",
		-- exceptions = terminalExceptions,
	},
	{
		source = { modifiers = {}, key = "escape" },
		target = { modifiers = {}, key = "capslock" },
		description = "Capslock to ESC",
	},
	{
		source = { modifiers = { "fn", "alt" }, key = "left" },
		target = { modifiers = { "fn", "ctrl" }, key = "left" },
		description = "Move cursor left by word",
		exceptions = terminalApps,
		allowModifiers = true,
	},
	{
		source = { modifiers = { "fn", "alt" }, key = "right" },
		target = { modifiers = { "fn", "ctrl" }, key = "right" },
		description = "Move cursor right by word",
		exceptions = terminalApps,
		allowModifiers = true,
	},
	{
		source = { modifiers = { "alt" }, key = "delete" },
		target = { modifiers = { "ctrl" }, key = "delete" },
		description = "Delete by one word",
		exceptions = terminalApps,
		allowModifiers = true,
	},
	-- {
	-- 	-- TODO: allow ability to remap a modifier key alone
	-- 	-- Useful in vim where ALT/OPT is swapped.
	-- 	source = { modifiers = { "alt" } },
	-- 	target = { modifiers = { "cmd" } },
	-- 	description = "ALT as OPT",
	-- 	only = terminalApps,
	-- },
	{
		-- All too easy to accidentally kill a tab or window.
		target = { modifiers = { "ctrl" }, key = "w" },
		description = "Disable Close tab/window",
		only = browserApps,
	},
	{
		target = { modifiers = { "cmd" }, key = "h" },
		debugHelper = true,
		description = "Disable CMD Hide",
	},
	{
		target = { modifiers = { "alt", "cmd" }, key = "h" },
		debugHelper = true,
		description = "Disable CMD+OPT Hide",
	},
}

-- Helper function to apply default values to a binding
local function applyDefaults(binding)
	for key, defaultValue in pairs(defaultValues) do
		if binding[key] == nil then
			binding[key] = defaultValue
		end
	end
	return binding
end

-- Helper function to check if current app is in exceptions list
local function isAppInExceptions(exceptions)
	if not exceptions or #exceptions == 0 then
		return false
	end

	local currentApp = hs.application.frontmostApplication()
	if not currentApp then
		return false
	end

	local bundleID = currentApp:bundleID()
	for _, exceptionBundle in ipairs(exceptions) do
		if bundleID == exceptionBundle then
			return true
		end
	end
	return false
end

-- Helper function to merge modifiers if allowModifiers is enabled
local function getMergedModifiers(targetModifiers, sourceModifiers, currentFlags, allowExtra)
	if not allowExtra then
		return targetModifiers
	end

	local mergedModifiers = {}
	-- Start with modifiers we are supposed to append
	for _, mod in ipairs(sourceModifiers) do
		table.insert(mergedModifiers, mod)
	end

	-- Add additional modifiers that weren't in source but are currently pressed
	local additionalMods = { "shift", "alt", "cmd", "ctrl", "fn" }
	for _, mod in ipairs(additionalMods) do
		-- If this modifier is currently pressed but not in target, add it
		if currentFlags[mod] and not hs.fnutils.contains(targetModifiers, mod) then
			table.insert(mergedModifiers, mod)
		end
	end

	return mergedModifiers
end

-- Debug helper function
local function showDebugInfo(binding, action, additionalInfo)
	if not binding.debugHelper then
		return
	end

	local message = string.format(
		"[%s] %s | %s",
		action,
		binding.description,
		table.concat(binding.target.modifiers, "+") .. "+" .. binding.target.key
	)
	if additionalInfo then
		message = message .. " | " .. additionalInfo
	end

	print(message)
	hs.alert.show(message, 2)
end

-- print("All keycodes:")
-- print(inspect(hs.keycodes.map))

-- Apply all key bindings
local enabledBindings = 0
local disabledBindings = 0

local function pushKey(modifiers, key, delay)
	delay = delay or 0.01
	hs.timer.doAfter(delay, function()
		hs.eventtap.keyStroke(modifiers, key, 0)
	end)
end

-- Configuration summary
print(string.format("Enhanced key bindings loaded: %d enabled, %d disabled", enabledBindings, disabledBindings))

-- Optional: Show which bindings have debug enabled
local debugEnabledCount = 0
for _, binding in ipairs(keyBindings) do
	binding = applyDefaults(binding)
	if binding.debugHelper then
		debugEnabledCount = debugEnabledCount + 1
	end
end

if debugEnabledCount > 0 then
	print(string.format("Debug mode enabled for %d bindings", debugEnabledCount))
end

local function debugKeys()
	hs.eventtap
		.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.systemDefined }, function(event)
			local type = event:getType()
			local flags = event:getFlags()
			if type == hs.eventtap.event.types.keyDown then
				print(inspect(flags) .. "\n" .. hs.keycodes.map[event:getKeyCode()])
			elseif type == hs.eventtap.event.types.systemDefined then
				local t = event:systemKey()
				if t.down then
					print("System key: " .. table.concat(flags, "+"))
				end
			end
			return true
		end)
		:start()
end
-- debugKeys()

-- helper: build a precise matcher for an exact modifier set
local function flagsMatchExact(flags, requiredMods, allowExtra)
	local need = { cmd = false, ctrl = false, alt = false, shift = false, fn = false }
	for _, m in ipairs(requiredMods or {}) do
		need[m] = true
	end
	local allMods = { "cmd", "ctrl", "alt", "shift", "fn" }
	for _, mod in ipairs(allMods) do
		local required = need[mod] or false
		local pressed = flags[mod] or false

		if allowExtra then
			if required and not pressed then
				return false
			end
		else
			if pressed ~= required then
				return false
			end
		end
	end

	return true
end

local function keycodeFor(name)
	return hs.keycodes.map[name]
end

local function newBinding(binding)
	local tap
	-- eventtap takes a function that returns true to consume the event, false to pass it through.
	-- Or it can return a table of events to replace the original with.
	-- TODO: we should try to return a modified event rather than synthesizing a new one. https://www.hammerspoon.org/docs/hs.eventtap.event.html#types
	tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
		local flags = e:getFlags()
		local wantCode = keycodeFor(binding.target.key)
		if e:getKeyCode() ~= wantCode then
			return false
		end
		if not flagsMatchExact(flags, binding.target.modifiers, binding.allowModifiers) then
			return false
		end

		-- only execute in the specified apps.
		if binding.only and #binding.only > 0 then
			if not hs.fnutils.contains(binding.only, hs.application.frontmostApplication():bundleID()) then
				showDebugInfo(binding, "SKIPPED: app not included", hs.application.frontmostApplication():bundleID())
				return false
			end
		end

		-- Exceptions: let the original go through unchanged
		if isAppInExceptions(binding.exceptions) then
			showDebugInfo(binding, "PASSTHROUGH (exception)", "eventtap")
			return false -- don't consume; system/app receives ctrl+arrow
		end

		-- Removes key press:
		if not binding.source or not binding.source.key then
			showDebugInfo(binding, "SINK", "Key remapped to nothing")
			return true -- consume original
		end

		local modsToSend = binding.source.modifiers
		-- Allow additional modifiers if they are held down
		if binding.allowModifiers then
			modsToSend = getMergedModifiers(binding.target.modifiers, binding.source.modifiers, flags, true)
			showDebugInfo(binding, "ALLOW extra modifiers", "extra: " .. table.concat(modsToSend, "+"))
		end

		showDebugInfo(binding, "REMAP (eventtap)")

		pushKey(modsToSend, binding.source.key, 0)
		tap:stop() -- prevents recursive triggering

		-- reenable after key press
		hs.timer.doAfter(0.001, function()
			tap:start()
		end)

		return true -- consume original
	end)
	tap:start()
end

for _, binding in ipairs(keyBindings) do
	-- Apply default values
	binding = applyDefaults(binding)
	-- Skip if binding is disabled

	enabledBindings = enabledBindings + 1

	if not binding.enabled then
		disabledBindings = disabledBindings + 1
		showDebugInfo(binding, "SKIPPED")
	else
		newBinding(binding)
	end
end
