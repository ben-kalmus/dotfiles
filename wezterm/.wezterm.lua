-- Pull in the wezterm API
local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
wezterm.plugin.update_all()

-- This will hold the configuration.
local config = wezterm.config_builder()
local act = wezterm.action

wezterm.on("update-right-status", function(window, pane)
	local current = window:active_workspace()
	local last_seen = wezterm.GLOBAL._last_seen_workspace

	-- First run on a window: just seed last_seen
	if last_seen == nil then
		wezterm.GLOBAL._last_seen_workspace = current
		return
	end
	-- If the workspace changed (via your helper, the launcher, palette, whatever):
	if current ~= last_seen then
		-- the one we were in becomes "previous"
		wezterm.GLOBAL.previous_workspace = last_seen
		-- and now we're here
		wezterm.GLOBAL._last_seen_workspace = current
	end
end)

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

	if wezterm.GLOBAL.previous_workspace == nil then
		wezterm.GLOBAL.previous_workspace = current_workspace
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
config.scrollback_lines = 100000
config.enable_scroll_bar = true

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
	{
		key = "l",
		mods = "LEADER",
		action = wezterm.action_callback(function(window, pane)
			toggle_last_workspace(window, pane)
		end),
	},
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

	-- Move around panes
	{ key = "h", mods = "LEADER|SHIFT", action = wezterm.action({ ActivatePaneDirection = "Left" }) },
	{ key = "j", mods = "LEADER|SHIFT", action = wezterm.action({ ActivatePaneDirection = "Down" }) },
	{ key = "k", mods = "LEADER|SHIFT", action = wezterm.action({ ActivatePaneDirection = "Up" }) },
	{ key = "l", mods = "LEADER|SHIFT", action = wezterm.action({ ActivatePaneDirection = "Right" }) },
	-- Session save and restore
	{
		key = "s",
		mods = "LEADER|SHIFT",
		action = wezterm.action_callback(function(win, pane)
			resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
			resurrect.window_state.save_window_action()
		end),
	},
	{
		key = "r",
		mods = "LEADER|SHIFT",
		action = wezterm.action_callback(function(win, pane)
			resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
				local type = string.match(id, "^([^/]+)") -- match before '/'
				id = string.match(id, "([^/]+)$") -- match after '/'
				id = string.match(id, "(.+)%..+$") -- remove file extention
				local opts = {
					relative = true,
					restore_text = true,
					on_pane_restore = resurrect.tab_state.default_on_pane_restore,

					window = pane:window(),
					close_open_tabs = true,
					-- window = win:mux_window(),
					-- tab = win:active_tab(),
				}
				if type == "workspace" then
					local state = resurrect.state_manager.load_state(id, "workspace")
					-- create new workspace with previous name
					-- Source: https://github.com/MLFlexer/resurrect.wezterm/issues/73#issuecomment-2572924018
					win:perform_action(
						wezterm.action.SwitchToWorkspace({
							name = state.workspace,
						}),
						pane
					)
					resurrect.workspace_state.restore_workspace(state, opts)
				elseif type == "window" then
					local state = resurrect.state_manager.load_state(id, "window")
					resurrect.window_state.restore_window(pane:window(), state, opts)
				elseif type == "tab" then
					local state = resurrect.state_manager.load_state(id, "tab")
					resurrect.tab_state.restore_tab(pane:tab(), state, opts)
				end
			end)
		end),
	},
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
