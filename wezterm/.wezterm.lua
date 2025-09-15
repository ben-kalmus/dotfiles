-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()
local act = wezterm.action

-- Track last tab and last workspace
local last_tab = nil
local last_workspace = nil

wezterm.on("update-right-status", function(window, pane)
	local tab = window:active_tab()
	if tab then
		last_tab = tab:tab_id()
	end
	local ws = window:active_workspace()
	if ws then
		last_workspace = ws
	end
end)

local function switch_to_last_workspace(window)
	if last_workspace then
		window:perform_action(act.SwitchToWorkspace({ name = last_workspace }), window:active_pane())
	end
end

local function switch_to_last_tab(window)
	if last_tab then
		window:perform_action(act.ActivateTab(last_tab), window:active_pane())
	end
end

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 48

-- or, changing the font size and color scheme.
config.font_size = 13
config.font = wezterm.font("Fira Code")
config.color_scheme = "Tokyo Night Moon"
config.window_background_opacity = 0.93

config.term = "xterm-256color"
config.enable_kitty_graphics = false

-- keybinds link https://wezterm.org/config/default-keys.html
-- remove ctrl - and ctrl = which resize window

-- LEADER key
config.leader = { key = "Space", mods = "SHIFT", timeout_milliseconds = 1000 }

config.keys = {
	{
		key = "m",
		mods = "CMD",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "-",
		mods = "CTRL",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "=",
		mods = "CTRL",
		action = wezterm.action.DisableDefaultAssignment,
	},
	-- tmux-like navigation
	-- Create splits easily (like tmux % and ")
	{ key = '"', mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "%", mods = "LEADER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	-- fuzzy search for tabs and workspaces
	{ key = "p", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
	-- Toggle last tab/window
	{ key = "k", mods = "LEADER", action = wezterm.action_callback(switch_to_last_tab) },
	-- Toggle last workspace
	{ key = "l", mods = "LEADER", action = wezterm.action_callback(switch_to_last_workspace) },
	-- Create new named workspace
	{
		key = "s",
		mods = "LEADER",
		action = act.PromptInputLine({
			description = "Enter new workspace name",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
				end
			end),
		}),
	},
	-- Create new named tab
	{
		key = "c",
		mods = "LEADER",
		action = act.PromptInputLine({
			description = "Enter new tab name",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					local tab, _ = window:mux_window():spawn_tab({}) -- new tab
					tab:set_title(line)
					window:perform_action(act.ActivateTab(tab:tab_id()), pane)
				end
			end),
		}),
	},
	-- Enter copy mode with Vim-style controls
	{ key = "[", mods = "LEADER", action = act.ActivateCopyMode },
}

-- Keybindings inside Copy Mode
local copy_mode = wezterm.gui.default_key_tables().copy_mode
table.insert(copy_mode, {
	{ key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
	{ key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
	{ key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
	{ key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
	{
		key = "v",
		mods = "NONE",
		action = act.CopyMode({ SetSelectionMode = "Cell" }),
	},
	{
		key = "v",
		mods = "SHIFT",
		action = act.CopyMode({ SetSelectionMode = "Line" }),
	},
	{
		key = "v",
		mods = "CTRL",
		action = act.CopyMode({ SetSelectionMode = "Block" }),
	},
	{
		key = "y",
		mods = "NONE",
		action = act.Multiple({
			{ CopyTo = "ClipboardAndPrimarySelection" },
			{ CopyMode = "ScrollToBottom" },
			{ CopyMode = "Close" },
		}),
	},
	{ key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
	-- Page movement
	{ key = "u", mods = "CTRL", action = act.CopyMode("PageUp") },
	{ key = "d", mods = "CTRL", action = act.CopyMode("PageDown") },
})

config.key_tables = { copy_mode = copy_mode }

-- Finally, return the configuration to wezterm:
return config
