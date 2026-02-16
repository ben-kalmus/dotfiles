-- Pull in the wezterm API
local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
wezterm.plugin.update_all()

-- This will hold the configuration.
local config = wezterm.config_builder()
local act = wezterm.action

local AUTO_SAVE_ALL_WORKSPACES_INTERVAL_SECONDS = 60 * 60

local function notify(window, title, message, timeout_ms)
	local timeout = timeout_ms or 4000
	local delivered = false
	local notify_err = nil

	if window then
		local ok, err = pcall(function()
			window:toast_notification(title, message, nil, timeout)
		end)
		delivered = ok
		notify_err = err
	end

	if not delivered and wezterm.gui then
		local windows = wezterm.gui.gui_windows()
		if windows and windows[1] then
			local ok, err = pcall(function()
				windows[1]:toast_notification(title, message, nil, timeout)
			end)
			delivered = ok
			notify_err = err
		end
	end

	if not delivered then
		wezterm.log_info(string.format("[%s] %s (notify error: %s)", title, message, tostring(notify_err)))
	end
end

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

local function save_all_open_workspaces_state()
	local workspace_states = {}

	for _, mux_win in ipairs(wezterm.mux.all_windows()) do
		local workspace = mux_win:get_workspace()
		if workspace and workspace ~= "" then
			if workspace_states[workspace] == nil then
				workspace_states[workspace] = {
					workspace = workspace,
					window_states = {},
				}
			end
			table.insert(workspace_states[workspace].window_states, resurrect.window_state.get_window_state(mux_win))
		end
	end

	local saved_count = 0
	for _, workspace_state in pairs(workspace_states) do
		resurrect.state_manager.save_state(workspace_state)
		saved_count = saved_count + 1
	end

	return saved_count
end

local function start_periodic_save_all_workspaces()
	if wezterm.GLOBAL._resurrect_periodic_save_started then
		return
	end
	wezterm.GLOBAL._resurrect_periodic_save_started = true

	local function tick()
		local ok, result = pcall(save_all_open_workspaces_state)
		if ok then
			wezterm.log_info(string.format("resurrect.wezterm: auto-saved %d workspaces", result))
		else
			wezterm.log_error("resurrect.wezterm: auto-save failed: " .. tostring(result))
		end
		wezterm.time.call_after(AUTO_SAVE_ALL_WORKSPACES_INTERVAL_SECONDS, tick)
	end

	wezterm.time.call_after(AUTO_SAVE_ALL_WORKSPACES_INTERVAL_SECONDS, tick)
end

start_periodic_save_all_workspaces()

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
config.enable_kitty_graphics = true
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
		key = "o",
		mods = "LEADER",
		action = wezterm.action_callback(function(win, pane)
			wezterm.log_info("resurrect.wezterm: save all requested (LEADER+o)")
			local ok, result = pcall(save_all_open_workspaces_state)
			if ok then
				local msg = string.format("Saved %d workspaces", result)
				wezterm.log_info("resurrect.wezterm: " .. msg)
				notify(win, "resurrect.wezterm", msg, 3500)
				return
			end

			local msg = "Failed to save all workspaces: " .. tostring(result)
			wezterm.log_error(msg)
			notify(win, "resurrect.wezterm", msg, 5000)
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
					relative = false,
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
	-- update all plugins
	{
		key = "u",
		mods = "LEADER",
		action = wezterm.action_callback(function(win, pane)
			wezterm.plugin.update_all()
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
