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
	for _, file in ipairs(files) do
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

-- Keep strong references to watchers; otherwise they can be garbage-collected.
local configWatchers = {}
local function startConfigWatchers()
	local watchPaths = { hs.configdir, os.getenv("HOME") .. "/.hammerspoon" }
	local started = {}

	for _, path in ipairs(watchPaths) do
		if not started[path] then
			local watcher = hs.pathwatcher.new(path, reloadConfig)
			if watcher then
				watcher:start()
				table.insert(configWatchers, watcher)
				started[path] = true
				print("Watching config path: " .. path)
			end
		end
	end
end
startConfigWatchers()

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
	inheritExtraModifiers = false, -- keep extra held modifiers (like Shift) when emitting
	enabled = true,
	debugHelper = false,
	exceptApps = {}, -- list of app bundle IDs to exclude from remapping
	onlyApps = {}, -- list of app bundle IDs to exclusively include
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

local finderApps = {
	"com.apple.finder",
}

-- Key binding definitions
local keyBindings = {
	-- trigger: key combo to listen for.
	-- emit: key combo to synthesize. If empty, the trigger is consumed (disabled).
	-- description: for debug purposes
	-- exceptApps: Apps to exclude from remapping (by bundle ID), to see bundle ID enter this into Hammerspoon console and alt tab into it:
	--             hs.timer.doAfter(3, function () print(hs.application.frontmostApplication():bundleID()) end)
	--
	-- onlyApps: List of apps (by bundle ID) to only enable this keybinding for.
	-- inheritExtraModifiers: if true, passes through extra held modifiers not in trigger.
	-- enabled: keybind ative
	-- passthrough: sends the activated keypress as well
	{
		emit = { modifiers = { "cmd" }, key = "c" },
		trigger = { modifiers = { "ctrl" }, key = "c" },
		description = "Copy",
		exceptApps = terminalApps,
		inheritExtraModifiers = true,
	},
	{
		emit = { modifiers = { "cmd" }, key = "v" },
		trigger = { modifiers = { "ctrl" }, key = "v" },
		description = "Paste",
		exceptApps = terminalApps,
		inheritExtraModifiers = true,
	},
	{
		emit = { modifiers = { "cmd" }, key = "b" },
		trigger = { modifiers = { "ctrl" }, key = "b" },
		description = "Bold",
		exceptApps = terminalApps,
	},
	{
		emit = { modifiers = { "cmd" }, key = "i" },
		trigger = { modifiers = { "ctrl" }, key = "i" },
		description = "Italic",
		exceptApps = terminalApps,
	},
	{
		emit = { modifiers = { "cmd" }, key = "x" },
		trigger = { modifiers = { "ctrl" }, key = "x" },
		description = "Cut",
		exceptApps = terminalApps,
	},
	{
		-- collides with ctrl-a which moves cursor to start
		enabled = true,
		emit = { modifiers = { "cmd" }, key = "a" },
		trigger = { modifiers = { "ctrl" }, key = "a" },
		description = "Select All",
		exceptApps = terminalApps,
	},
	{
		emit = { modifiers = { "cmd" }, key = "z" },
		trigger = { modifiers = { "ctrl" }, key = "z" },
		description = "Undo",
		exceptApps = terminalApps,
	},
	{
		emit = { modifiers = { "shift", "cmd" }, key = "z" },
		trigger = { modifiers = { "shift", "ctrl" }, key = "z" },
		description = "Redo (z key)",
		exceptApps = terminalApps,
	},
	{
		emit = { modifiers = { "cmd", "shift" }, key = "z" },
		trigger = { modifiers = { "ctrl" }, key = "y" },
		description = "Redo",
		exceptApps = terminalApps,
	},
	{
		emit = { modifiers = { "cmd" }, key = "r" },
		trigger = { modifiers = { "ctrl" }, key = "r" },
		description = "Refresh / Reload",
		exceptApps = terminalApps,
		inheritExtraModifiers = true,
	},
	{
		emit = { modifiers = { "cmd" }, key = "p" },
		trigger = { modifiers = { "ctrl" }, key = "p" },
		description = "Command Pallette / Print",
		exceptApps = terminalApps,
		inheritExtraModifiers = true,
	},
	{
		emit = { modifiers = { "cmd" }, key = "f" },
		trigger = { modifiers = { "ctrl" }, key = "f" },
		description = "Find",
		exceptApps = terminalApps,
	},
	{
		emit = { modifiers = { "cmd" }, key = "left" },
		trigger = { key = "home" },
		description = "HOME key",
		exceptApps = terminalApps,
		inheritExtraModifiers = true,
	},
	{
		emit = { modifiers = { "cmd" }, key = "s" },
		trigger = { modifiers = { "ctrl" }, key = "s" },
		description = "Save",
		exceptApps = terminalApps,
		inheritExtraModifiers = true,
	},
	{
		emit = { modifiers = { "cmd" }, key = "right" },
		trigger = { key = "end" },
		description = "END key",
		exceptApps = terminalApps,
		inheritExtraModifiers = true,
	},
	{
		emit = { modifiers = { "cmd" }, key = "t" },
		trigger = { modifiers = { "ctrl" }, key = "t" },
		inheritExtraModifiers = true,
		onlyApps = { "com.google.Chrome", "org.mozilla.firefox" },
		description = "New Tab",
		-- exceptApps = terminalExceptions,
	},
	{
		emit = { modifiers = {}, key = "escape" },
		trigger = { modifiers = {}, key = "capslock" },
		description = "Capslock to ESC",
	},
	{
		emit = { modifiers = { "fn", "alt" }, key = "left" },
		trigger = { modifiers = { "fn", "ctrl" }, key = "left" },
		description = "Move cursor left by word",
		exceptApps = terminalApps,
		inheritExtraModifiers = true,
	},
	{
		emit = { modifiers = { "fn", "alt" }, key = "right" },
		trigger = { modifiers = { "fn", "ctrl" }, key = "right" },
		description = "Move cursor right by word",
		exceptApps = terminalApps,
		inheritExtraModifiers = true,
	},
	{
		emit = { modifiers = { "alt" }, key = "delete" },
		trigger = { modifiers = { "ctrl" }, key = "delete" },
		description = "Delete by one word",
		exceptApps = terminalApps,
		inheritExtraModifiers = true,
	},
	{
		emit = { modifiers = { "cmd" }, key = "delete" },
		trigger = { modifiers = {}, key = "delete" },
		description = "Finder: Backspace moves file to Trash",
		onlyApps = finderApps,
	},
	{
		emit = { modifiers = { "cmd" }, key = "delete" },
		trigger = { modifiers = {}, key = "forwarddelete" },
		description = "Finder: ForwardDelete moves file to Trash",
		onlyApps = finderApps,
	},
	{
		emit = { modifiers = { "cmd" }, key = "delete" },
		trigger = { modifiers = { "fn" }, key = "delete" },
		description = "Finder: Fn+Delete moves file to Trash",
		onlyApps = finderApps,
	},
	-- {
	-- 	-- TODO: allow ability to remap a modifier key alone
	-- 	-- Useful in vim where ALT/OPT is swapped.
	-- 	emit = { modifiers = { "alt" } },
	-- 	trigger = { modifiers = { "cmd" } },
	-- 	description = "ALT as OPT",
	-- 	onlyApps = terminalApps,
	-- },
	{
		-- All too easy to accidentally kill a tab or window.
		trigger = { modifiers = { "ctrl" }, key = "w" },
		description = "Disable Close tab/window",
		onlyApps = browserApps,
	},
	{
		trigger = { modifiers = { "cmd" }, key = "h" },
		debugHelper = true,
		description = "Disable CMD Hide",
	},
	{
		trigger = { modifiers = { "alt", "cmd" }, key = "h" },
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

-- Helper function to check if current app is in a given app list
local function isFrontmostAppInList(appList)
	if not appList or #appList == 0 then
		return false
	end

	local currentApp = hs.application.frontmostApplication()
	if not currentApp then
		return false
	end

	local bundleID = currentApp:bundleID()
	for _, appBundleID in ipairs(appList) do
		if bundleID == appBundleID then
			return true
		end
	end
	return false
end

-- Helper function to merge emitted modifiers with additional held modifiers
local function getMergedModifiers(triggerModifiers, emitModifiers, currentFlags, inheritExtraModifiers)
	triggerModifiers = triggerModifiers or {}
	emitModifiers = emitModifiers or {}
	currentFlags = currentFlags or {}

	if not inheritExtraModifiers then
		return emitModifiers
	end

	local mergedModifiers = {}
	-- Start with modifiers configured in the emitted key stroke
	for _, mod in ipairs(emitModifiers) do
		table.insert(mergedModifiers, mod)
	end

	-- Add additional held modifiers that weren't part of the trigger combo
	local additionalMods = { "shift", "alt", "cmd", "ctrl", "fn" }
	for _, mod in ipairs(additionalMods) do
		if currentFlags[mod] and not hs.fnutils.contains(triggerModifiers, mod) then
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

	local trigger = binding.trigger or {}
	local triggerMods = trigger.modifiers or {}
	local triggerCombo = ((#triggerMods > 0) and (table.concat(triggerMods, "+") .. "+") or "") .. tostring(trigger.key or "?")

	local message = string.format(
		"[%s] %s | %s",
		action,
		binding.description,
		triggerCombo
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

local function isModifierKey(name)
	return hs.fnutils.contains({ "cmd", "ctrl", "alt", "shift", "fn", "capslock" }, name)
end

local function newBinding(binding)
	local tap
	-- eventtap takes a function that returns true to consume the event, false to pass it through.
	-- Or it can return a table of events to replace the original with.
	-- TODO: we should try to return a modified event rather than synthesizing a new one. https://www.hammerspoon.org/docs/hs.eventtap.event.html#types
	tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.flagsChanged }, function(e)
		local flags = e:getFlags()
		local eventType = e:getType()
		local wantCode = keycodeFor(binding.trigger.key)
		local triggerIsModifier = isModifierKey(binding.trigger.key)

		-- Modifier keys (like capslock) emit flagsChanged, not keyDown.
		if triggerIsModifier then
			if eventType ~= hs.eventtap.event.types.flagsChanged then
				return false
			end
		else
			if eventType ~= hs.eventtap.event.types.keyDown then
				return false
			end
		end

		if e:getKeyCode() ~= wantCode then
			return false
		end
		if not flagsMatchExact(flags, binding.trigger.modifiers, binding.inheritExtraModifiers) then
			return false
		end

		-- Only execute in the specified apps.
		if binding.onlyApps and #binding.onlyApps > 0 then
			if not hs.fnutils.contains(binding.onlyApps, hs.application.frontmostApplication():bundleID()) then
				showDebugInfo(binding, "SKIPPED: app not included", hs.application.frontmostApplication():bundleID())
				return false
			end
		end

		-- exceptApps: let the original go through unchanged
		if isFrontmostAppInList(binding.exceptApps) then
			showDebugInfo(binding, "PASSTHROUGH (exception)", "eventtap")
			return false -- don't consume; system/app receives ctrl+arrow
		end

		-- Removes key press:
		if not binding.emit or not binding.emit.key then
			showDebugInfo(binding, "SINK", "Key remapped to nothing")
			return true -- consume original
		end

		local modsToSend = binding.emit.modifiers or {}
		-- Allow additional modifiers if they are held down
		if binding.inheritExtraModifiers then
			modsToSend = getMergedModifiers(binding.trigger.modifiers, binding.emit.modifiers, flags, true)
			showDebugInfo(binding, "ALLOW extra modifiers", "extra: " .. table.concat(modsToSend, "+"))
		end

		showDebugInfo(binding, "REMAP (eventtap)")

		tap:stop() -- prevents recursive triggering

		-- Caps Lock toggles OS state even when consumed; force it back off.
		if binding.trigger.key == "capslock" then
			hs.hid.capslock.set(false)
		end

		pushKey(modsToSend, binding.emit.key, 0)

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
