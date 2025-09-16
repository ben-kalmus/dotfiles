-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()
local act = wezterm.action

-- Track last tab and last workspace
local function switch_workspace(window, pane, workspace)
    local current_workspace = window:active_workspace()
	if current_workspace == workspace then
		return
	end

	window:perform_action(
		act.SwitchToWorkspace({
			name = workspace,
		}),
		pane
	)
	wezterm.GLOBAL.previous_workspace = current_workspace
end

local function toggle_last_workspace(window, pane)
	local current_workspace = window:active_workspace()
	local workspace = wezterm.GLOBAL.previous_workspace

	if current_workspace == workspace or wezterm.GLOBAL.previous_workspace == nil then
		return
	end

	switch_workspace(window, pane, workspace)
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
	{ key = "Space", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
	-- Toggle last tab/window
	{ key = "k", mods = "LEADER", action = wezterm.action.ActivateLastTab },
	-- Toggle last workspace
	{ key = "l", mods = "LEADER", action = wezterm.action_callback(toggle_last_workspace) },
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
local default_copy_mode = wezterm.gui.default_key_tables().copy_mode
local my_copy_mode = {
	{ key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
	{ key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
	{ key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
	{ key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
	{ key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
	{ key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
	{
		key = "V",
		mods = "NONE",
		action = act.CopyMode({ SetSelectionMode = "Cell" }),
	},
	{
		key = "V",
		mods = "SHIFT",
		action = act.CopyMode({ SetSelectionMode = "Line" }),
	},
	{
		key = "V",
		mods = "CTRL",
		action = act.CopyMode({ SetSelectionMode = "Block" }),
	},
	{ key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
}

local function merge_tables(base, extra)
	local result = {}
	for _, v in ipairs(base) do
		table.insert(result, v)
	end
	for _, v in ipairs(extra) do
		table.insert(result, v)
	end
end

config.key_tables = { copy_mode = merge_tables(default_copy_mode, my_copy_mode) }

-- Finally, return the configuration to wezterm:
return config
