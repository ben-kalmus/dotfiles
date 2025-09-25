-- Reload config when files change
local function reloadConfig(files)
	doReload = false
	for _, file in pairs(files) do
		if file:sub(-4) == ".lua" then
			doReload = true
		end
	end
	if doReload then
		hs.reload()
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
	debugHelper = true,
	exceptions = {}, -- list of app bundle IDs to exclude from remapping
}

-- Key binding definitions
local keyBindings = {
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
		source = { modifiers = { "cmd" }, key = "s" },
		target = { modifiers = { "ctrl" }, key = "s" },
		description = "Save",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd" }, key = "f" },
		target = { modifiers = { "ctrl" }, key = "f" },
		description = "Find",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "cmd" }, key = "p" },
		target = { modifiers = { "ctrl" }, key = "p" },
		description = "Print",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
	},
	{
		source = { modifiers = { "ctrl" }, key = "left" },
		target = { modifiers = { "alt" }, key = "left" },
		description = "Move cursor left by word",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
		preserveAdditionalModifiers = true,
	},
	{
		source = { modifiers = { "ctrl" }, key = "right" },
		target = { modifiers = { "alt" }, key = "right" },
		description = "Move cursor right by word",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
		preserveAdditionalModifiers = true,
	},
	{
		source = { modifiers = { "cmd" }, key = "w" },
		target = { modifiers = { "ctrl" }, key = "w" },
		description = "Close tab/window",
		exceptions = { "com.github.wez.wezterm", "com.apple.Terminal" },
		enabled = false, -- Disabled by default as it might conflict with macOS window closing
		debugHelper = true,
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
local function getMergedModifiers(sourceModifiers, targetModifiers, currentFlags, preserveAdditional)
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

	local message = string.format("[%s] %s", action, binding.description)
	if additionalInfo then
		message = message .. " | " .. additionalInfo
	end

	print(message)
	hs.alert.show(message, 2)
end

-- Apply all key bindings
local enabledBindings = 0
local disabledBindings = 0

for _, binding in ipairs(keyBindings) do
	-- Apply default values
	binding = applyDefaults(binding)

	-- Skip if binding is disabled
	if not binding.enabled then
		disabledBindings = disabledBindings + 1
		showDebugInfo(binding, "SKIPPED", "Binding is disabled")
		goto continue
	end

	enabledBindings = enabledBindings + 1

	-- bind a hotkey on target mapping
	hs.hotkey.bind(binding.target.modifiers, binding.target.key, function()
		showDebugInfo(binding, "TRIGGERED", "Checking conditions...")

		-- Skip if current app is in exceptions
		if isAppInExceptions(binding.exceptions) then
			-- Pass through the normal key combination
			hs.eventtap.keyStroke(binding.target.modifiers, binding.target.key)
			showDebugInfo(
				binding,
				"App in exceptions list - passing through",
				string.format("Sent %s+%s", table.concat(binding.target.modifiers, "+"), binding.target.key)
			)
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
		hs.eventtap.keyStroke(modifiers, binding.source.key)
		showDebugInfo(
			binding,
			"EXECUTED",
			string.format("Sent %s+%s", table.concat(modifiers, "+"), binding.source.key)
		)
	end)

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
