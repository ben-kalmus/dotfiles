package.path = table.concat({
	package.path,
	hs.configdir .. "/vendor/?.lua",
	hs.configdir .. "/vendor/?/init.lua",
	hs.configdir .. "/vendor/?/?.lua", -- lets require("inspect") find vendor/inspect/inspect.lua
}, ";")

local inspect = require("inspect")

-- Reload config when files change
local function reloadConfig(files)
	doReload = false
	for _, file in pairs(files) do
		if file:sub(-4) == ".lua" then
			doReload = true
		end
	end

	if doReload then
		hs.timer.doAfter(0.5, function()
			hs.reload()
		end)
	end
end
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

hs.alert.show("Hammerspoon config loaded")

-- ================================================================================================
-- Mac to Linux key binding configuration
-- ================================================================================================

-- Default values for optional fields
local defaultValues = {
	preserveAdditionalModifiers = false, -- allows you to hold other modifiers (like Shift) while remapping
	enabled = true,
	debugHelper = false,
	exceptions = {}, -- list of app bundle IDs to exclude from remapping
	passthrough = false, -- sends the activated keypress as well
}

-- Key binding definitions
local keyBindings = {
	-- source: key to send to Mac OS. If empty, no events are fired. This is useful to disable a key.
	-- target: key to activate on
	-- description: for debug purposes
	-- exceptions: App to exclude from remapping (by bundle ID), to see bundle ID use: hs.application.frontmostApplication():bundleID()
	-- only: List of Apps (by bundle ID) to only enable this keybinding for.
	-- enabled: keybind ative
	-- passthrough: sends the activated keypress as well
	{
		source = { modifiers = { "cmd" }, key = "c" },
		target = { modifiers = { "ctrl" }, key = "c" },
		description = "Copy",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd" }, key = "v" },
		target = { modifiers = { "ctrl" }, key = "v" },
		description = "Paste",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd" }, key = "x" },
		target = { modifiers = { "ctrl" }, key = "x" },
		description = "Cut",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		-- collides with ctrl-a which moves cursor to start
		enabled = true,
		source = { modifiers = { "cmd" }, key = "a" },
		target = { modifiers = { "ctrl" }, key = "a" },
		description = "Select All",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd" }, key = "z" },
		target = { modifiers = { "ctrl" }, key = "z" },
		description = "Undo",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd", "shift" }, key = "z" },
		target = { modifiers = { "ctrl" }, key = "y" },
		description = "Redo",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd" }, key = "r" },
		target = { modifiers = { "ctrl" }, key = "r" },
		description = "Refresh / Reload",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd" }, key = "p" },
		target = { modifiers = { "ctrl" }, key = "p" },
		description = "Command Pallette / Print",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd", "shift" }, key = "p" },
		target = { modifiers = { "ctrl", "shift" }, key = "p" },
		description = "Command Pallette / Print",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd" }, key = "f" },
		target = { modifiers = { "ctrl" }, key = "f" },
		description = "Find",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd" }, key = "t" },
		target = { modifiers = { "ctrl" }, key = "t" },
        only = { "com.google.Chrome" , "org.mozilla.firefox" },
		description = "New Tab",
		-- exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = {}, key = "escape" },
		target = { modifiers = {}, key = "capslock" },
		description = "Capslock to ESC",
	},
	-- {
	-- 	source = { modifiers = { "fn", "alt" }, key = "left" },
	-- 	target = { modifiers = { "fn", "ctrl" }, key = "left" },
	-- 	description = "Move cursor left by word",
	-- 	exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	-- 	debugHelper = true,
	-- 	-- preserveAdditionalModifiers = true,
	-- },
	-- {
	-- 	debugHelper = true,
	-- 	source = { modifiers = { "fn", "alt" }, key = "right" },
	-- 	target = { modifiers = { "fn", "ctrl" }, key = "right" },
	-- 	description = "Move cursor right by word",
	-- 	exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	-- 	-- preserveAdditionalModifiers = true,
	-- },
	{
		source = { modifiers = { "cmd" }, key = "w" },
		target = { modifiers = { "ctrl" }, key = "w" },
		description = "Close tab/window",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
		enabled = false, -- Disabled by default as it might conflict with macOS window closing
		debugHelper = true,
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

-- Helper function to merge modifiers if preserveAdditionalModifiers is enabled
local function getMergedModifiers(targetModifiers, sourceModifiers, currentFlags, preserveAdditional)
	if not preserveAdditional then
		return targetModifiers
	end

	-- Start with target modifiers
	local mergedModifiers = {}
	for _, mod in ipairs(targetModifiers) do
		table.insert(mergedModifiers, mod)
	end

	-- Add additional modifiers that weren't in source but are currently pressed
	local additionalMods = { "shift", "alt", "cmd", "ctrl", "fn" }
	for _, mod in ipairs(additionalMods) do
		-- If this modifier is currently pressed but not in source or target, add it
		if
			currentFlags[mod]
			and not hs.fnutils.contains(sourceModifiers, mod)
			and not hs.fnutils.contains(targetModifiers, mod)
		then
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

print("All keycodes:")
print(inspect(hs.keycodes.map))

-- Apply all key bindings
local enabledBindings = 0
local disabledBindings = 0

local function pushKey(modifiers, key, delay)
  delay = delay or 0.01
  hs.timer.doAfter(delay, function()
    hs.eventtap.keyStroke(modifiers, key, 0)
  end)
end

showAppInfo = false

for _, binding in ipairs(keyBindings) do
    -- Apply default values
    binding = applyDefaults(binding)
    -- Skip if binding is disabled
    if not binding.enabled then
        disabledBindings = disabledBindings + 1
        showDebugInfo(binding, "SKIPPED")
        goto continue
    end

    enabledBindings = enabledBindings + 1

    local hk
    hk = hs.hotkey.bind(binding.target.modifiers, binding.target.key, nil, function()
        showDebugInfo(binding, "TRIGGERED")

        if not binding.source or not binding.source.key then
            showDebugInfo(binding, "SINK", "Key remapped to nothing")
            return
        end

        if showAppInfo == true then 
              print( hs.application.frontmostApplication():bundleID())
        end

        if binding.only and #binding.only > 0 then
            if not hs.fnutils.contains(binding.only, hs.application.frontmostApplication():bundleID()) then
                showDebugInfo(binding, "SKIPPED: app not included", hs.application.frontmostApplication():bundleID())
                return
            end
        end

          -- Skip if current app is in exceptions
          if isAppInExceptions(binding.exceptions) then
              -- Pass through the normal key combination
              pushKey(binding.target.modifiers, binding.target.key, 0)
              hk:disable()    -- prevent recursion
              hs.timer.doAfter(0.01, function()
                  hk:enable()
              end)

              showDebugInfo(binding, "PASSTHROUGH: App in exception " .. hs.application.frontmostApplication():bundleID())
              return
          end

          -- Determine target modifiers (with potential additional modifier preservation)
          local modifiers = binding.source.modifiers
          if binding.preserveAdditionalModifiers then
              local currentFlags = hs.eventtap.checkKeyboardModifiers()
              modifiers = getMergedModifiers(binding.target.modifiers, binding.source.modifiers, currentFlags, true)
              showDebugInfo(binding, "MODIFIERS", "Preserved additional modifiers")
          end

          -- Send the original mac key combination
          pushKey(modifiers, binding.source.key)
          showDebugInfo(binding, "EXECUTED")
          -- hk:disable()

          -- If passthrough is enabled, also send the target key combination
          if binding.passthrough then
              pushKey(binding.target.modifiers, binding.target.key)
              showDebugInfo(binding, "PASSTHROUGH: Sent target key as well")
          end
      end, nil)

    ::continue::
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

-- hs.hotkey.
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
