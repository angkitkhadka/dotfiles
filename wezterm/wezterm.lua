-- WezTerm: tmux-style keys, direct conversion of my tmux configuration
local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find("windows") ~= nil
local is_mac = wezterm.target_triple:find("apple") ~= nil

-- Settings
local CITY = "Toronto"
local WSL_DISTRO = "Ubuntu-22.04"
local USE_RESURRECT = true -- layout save/restore plugin

local C = {
	purple = "#bb9af7",
	cyan = "#7dcfff",
	green = "#9ece6a",
	fg = "#c0caf5",
	dim = "#8a8a8a",
	border = "#3b4261",
	black = "#080808",
	bg = "#1a1b26",
}

-- UIs
config.font = wezterm.font_with_fallback({ "JetBrains Mono", "Menlo", "Consolas" })
config.font_size = 19.0
config.color_scheme = "Tokyo Night"
config.window_padding = { left = 10, right = 10, top = 10, bottom = 6 }
config.default_cursor_style = "SteadyBar"
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.7 }
config.scrollback_lines = 50000
config.check_for_updates = false

-- Status bar lives in the tab bar, so keep it always visible
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.status_update_interval = 1000

config.enable_kitty_graphics = true

config.colors = {
	tab_bar = {
		background = C.bg,
		new_tab = { bg_color = C.bg, fg_color = C.dim },
		new_tab_hover = { bg_color = C.border, fg_color = C.fg },
	},
	split = C.border,
	selection_bg = C.purple,
	selection_fg = C.black,
}

-- if on macbook
if is_mac then
	config.send_composed_key_when_left_alt_is_pressed = false
	config.send_composed_key_when_right_alt_is_pressed = true
end

if is_windows then
	-- Default to WSL Ubuntu; fall back to the first distro found
	local wanted = "WSL:" .. WSL_DISTRO
	local domains = wezterm.default_wsl_domains()
	local found = false
	for _, d in ipairs(domains) do
		if d.name == wanted then
			found = true
		end
	end
	if found then
		config.default_domain = wanted
	elseif #domains > 0 then
		wezterm.log_warn("WSL distro " .. WSL_DISTRO .. " not found; using " .. domains[1].name)
		config.default_domain = domains[1].name
	end
	config.launch_menu = {
		{ label = "PowerShell", args = { "powershell.exe", "-NoLogo" } },
		{ label = "Command Prompt", args = { "cmd.exe" } },
	}
end

-- Session persistence - resurrect.wezterm
local resurrect
if USE_RESURRECT then
	local ok, plugin = pcall(wezterm.plugin.require, "https://github.com/MLFlexer/resurrect.wezterm")
	if ok then
		resurrect = plugin
	else
		wezterm.log_error("resurrect.wezterm failed to load: " .. tostring(plugin))
	end
end

if resurrect then
	if is_windows then
		resurrect.state_manager.change_state_save_dir(wezterm.home_dir .. "\\.local\\state\\wezterm-resurrect\\")
	end
	resurrect.state_manager.set_max_nlines(1000)
	-- autosave every 5 min
	resurrect.state_manager.periodic_save({
		interval_seconds = 300,
		save_workspaces = true,
		save_windows = true,
		save_tabs = true,
	})
end

-- Prefix (Ctrl+b, Ctrl+a, and Cmd+b on macOS)
local function prefix()
	return act.ActivateKeyTable({ name = "prefix", one_shot = true })
end

-- tmux config conversion of pane resizing
local function repeat_table()
	return act.ActivateKeyTable({
		name = "pane_repeat",
		one_shot = false,
		timeout_milliseconds = 700,
		until_unknown = true,
	})
end
local function rep(action)
	return act.Multiple({ action, repeat_table() })
end

config.keys = {
	{ key = "b", mods = "CTRL", action = prefix() },
	{ key = "a", mods = "CTRL", action = prefix() },
}

-- Cmd works wherever Ctrl does
if is_mac then
	table.insert(config.keys, { key = "b", mods = "SUPER", action = prefix() })
	table.insert(config.keys, { key = "a", mods = "SUPER", action = prefix() })
end
if is_windows then
	-- F11 (or Alt+Enter) toggles fullscreen
	table.insert(config.keys, { key = "F11", action = act.ToggleFullScreen })
	-- Ctrl+C copies if text is selected, otherwise sends the normal interrupt
	table.insert(config.keys, {
		key = "c",
		mods = "CTRL",
		action = wezterm.action_callback(function(window, pane)
			local selection = window:get_selection_text_for_pane(pane)
			if selection ~= "" then
				window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
				window:perform_action(act.ClearSelection, pane)
			else
				window:perform_action(act.SendKey({ key = "c", mods = "CTRL" }), pane)
			end
		end),
	})
	-- Ctrl+V and Ctrl+Shift+V pasting
	table.insert(config.keys, { key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") })
end

local function save_session()
	if resurrect then
		resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
	end
end

local rename_workspace = act.PromptInputLine({
	description = "Rename workspace",
	action = wezterm.action_callback(function(window, pane, line)
		if line and line ~= "" then
			wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
			save_session()
		end
	end),
})

local new_workspace = act.PromptInputLine({
	description = "New workspace name",
	action = wezterm.action_callback(function(window, pane, line)
		if line and line ~= "" then
			window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
		end
	end),
})

-- prefix + s: pick a workspace, or create one
local workspace_picker = wezterm.action_callback(function(window, pane)
	local choices = {}
	for _, name in ipairs(wezterm.mux.get_workspace_names()) do
		table.insert(choices, { id = name, label = name })
	end
	table.insert(choices, { id = "__new__", label = "+ New workspace..." })
	window:perform_action(
		act.InputSelector({
			title = "Workspaces",
			choices = choices,
			fuzzy = true,
			action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
				if not id then
					return
				end
				if id == "__new__" then
					inner_window:perform_action(new_workspace, inner_pane)
				else
					inner_window:perform_action(act.SwitchToWorkspace({ name = id }), inner_pane)
				end
			end),
		}),
		pane
	)
end)

local prefix_keys = {
	-- Send the prefix through to the program
	{ key = "b", mods = "CTRL", action = act.SendKey({ key = "b", mods = "CTRL" }) },
	{ key = "a", mods = "CTRL", action = act.SendKey({ key = "a", mods = "CTRL" }) },
	{ key = "Escape", action = act.Nop },

	{ key = "r", action = act.ReloadConfiguration },

	-- Panes: move (hjkl) and resize (HJKL)
	{ key = "h", action = rep(act.ActivatePaneDirection("Left")) },
	{ key = "j", action = rep(act.ActivatePaneDirection("Down")) },
	{ key = "k", action = rep(act.ActivatePaneDirection("Up")) },
	{ key = "l", action = rep(act.ActivatePaneDirection("Right")) },
	{ key = "H", mods = "SHIFT", action = rep(act.AdjustPaneSize({ "Left", 5 })) },
	{ key = "J", mods = "SHIFT", action = rep(act.AdjustPaneSize({ "Down", 5 })) },
	{ key = "K", mods = "SHIFT", action = rep(act.AdjustPaneSize({ "Up", 5 })) },
	{ key = "L", mods = "SHIFT", action = rep(act.AdjustPaneSize({ "Right", 5 })) },

	-- tmux defaults
	{ key = "%", mods = "SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = '"', mods = "SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "c", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "n", action = act.ActivateTabRelative(1) },
	{ key = "p", action = act.ActivateTabRelative(-1) },
	{ key = "z", action = act.TogglePaneZoomState },
	{ key = "x", action = act.CloseCurrentPane({ confirm = true }) },
	{ key = "&", mods = "SHIFT", action = act.CloseCurrentTab({ confirm = true }) },
	{ key = "o", action = act.ActivatePaneDirection("Next") },
	{ key = "q", action = act.PaneSelect({ alphabet = "123456789" }) },
	{ key = "{", mods = "SHIFT", action = act.RotatePanes("CounterClockwise") },
	{ key = "}", mods = "SHIFT", action = act.RotatePanes("Clockwise") },
	{ key = "[", action = act.ActivateCopyMode },
	{ key = "]", action = act.PasteFrom("Clipboard") },
	{ key = "w", action = act.ShowTabNavigator },
	{ key = "s", action = workspace_picker },
	{ key = ":", mods = "SHIFT", action = act.ActivateCommandPalette },
	{ key = "N", mods = "SHIFT", action = act.ShowLauncher }, -- shell picker

	-- Rename tab (,) and workspace ($)
	{
		key = ",",
		action = act.PromptInputLine({
			description = "Rename tab",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},
	{ key = "$", mods = "SHIFT", action = rename_workspace },
	{ key = "$", mods = "NONE", action = rename_workspace },
	{ key = "R", mods = "SHIFT", action = rename_workspace }, -- easier alternative to $
	{ key = "S", mods = "SHIFT", action = new_workspace }, -- named new workspace
}

for i = 1, 9 do -- tabs start at 1
	table.insert(prefix_keys, { key = tostring(i), action = act.ActivateTab(i - 1) })
end

if resurrect then
	-- prefix + Ctrl-s: save now
	table.insert(prefix_keys, {
		key = "s",
		mods = "CTRL",
		action = wezterm.action_callback(function(win, pane)
			resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
			win:toast_notification("WezTerm", "Session saved ✓", nil, 1500)
		end),
	})
	-- prefix + Ctrl-r: pick a saved state to restore
	table.insert(prefix_keys, {
		key = "r",
		mods = "CTRL",
		action = wezterm.action_callback(function(win, pane)
			resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
				local type = string.match(id, "^([^/]+)")
				id = string.match(id, "([^/]+)$")
				id = string.match(id, "(.+)%..+$")
				local opts = {
					relative = true,
					restore_text = false,
					on_pane_restore = resurrect.tab_state.default_on_pane_restore,
				}
				if type == "workspace" then
					local state = resurrect.state_manager.load_state(id, "workspace")
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
	})
end

-- mirror every Ctrl binding in the prefix table as Cmd
if is_mac then
	for i = 1, #prefix_keys do
		local k = prefix_keys[i]
		if k.mods == "CTRL" then
			table.insert(prefix_keys, { key = k.key, mods = "SUPER", action = k.action })
		end
	end
end

local repeat_keys = {
	{ key = "Escape", action = act.PopKeyTable },
	{ key = "h", action = act.ActivatePaneDirection("Left") },
	{ key = "j", action = act.ActivatePaneDirection("Down") },
	{ key = "k", action = act.ActivatePaneDirection("Up") },
	{ key = "l", action = act.ActivatePaneDirection("Right") },
	{ key = "H", mods = "SHIFT", action = act.AdjustPaneSize({ "Left", 5 }) },
	{ key = "J", mods = "SHIFT", action = act.AdjustPaneSize({ "Down", 5 }) },
	{ key = "K", mods = "SHIFT", action = act.AdjustPaneSize({ "Up", 5 }) },
	{ key = "L", mods = "SHIFT", action = act.AdjustPaneSize({ "Right", 5 }) },
}

config.key_tables = {
	prefix = prefix_keys,
	pane_repeat = repeat_keys,
}

-- Copy mode (vim visual mode): make sure / n N exist on top of the defaults
local function ensure_key(tbl, key, mods, action)
	for _, k in ipairs(tbl) do
		if k.key == key and (k.mods or "NONE") == mods then
			return
		end
	end
	table.insert(tbl, { key = key, mods = mods, action = action })
end

if wezterm.gui then
	local copy_mode = wezterm.gui.default_key_tables().copy_mode
	ensure_key(copy_mode, "/", "NONE", act.Search("CurrentSelectionOrEmptyString"))
	ensure_key(copy_mode, "n", "NONE", act.CopyMode("NextMatch"))
	ensure_key(copy_mode, "N", "SHIFT", act.CopyMode("PriorMatch"))
	config.key_tables.copy_mode = copy_mode
end

-- Status bar
local cache = { uptime = "", uptime_at = 0, weather = "", weather_at = 0 }

local function fmt_uptime(s)
	local d = math.floor(s / 86400)
	local h = math.floor((s % 86400) / 3600)
	if d > 0 and h > 0 then
		return d .. "d " .. h .. "h"
	end
	if d > 0 then
		return d .. "d"
	end
	return h .. "h"
end

local function read_uptime_seconds()
	if is_mac then
		local ok, success, out = pcall(wezterm.run_child_process, { "sysctl", "-n", "kern.boottime" })
		if ok and success then
			local boot = out:match("sec = (%d+)")
			if boot then
				return os.time() - tonumber(boot)
			end
		end
	-- WSL2 uptime
	elseif is_windows then
		local ok, success, out = pcall(wezterm.run_child_process, { "wsl.exe", "-e", "cat", "/proc/uptime" })
		if ok and success then
			local s = out:match("^%s*(%d+)")
			if s then
				return tonumber(s)
			end
		end
	else
		local f = io.open("/proc/uptime", "r")
		if f then
			local line = f:read("*l")
			f:close()
			local s = line and line:match("^(%d+)")
			if s then
				return tonumber(s)
			end
		end
	end
	return nil
end

-- refreshed every 60 s
local function uptime()
	local now = os.time()
	if now - cache.uptime_at >= 60 then
		cache.uptime_at = now
		local s = read_uptime_seconds()
		if s then
			cache.uptime = fmt_uptime(s)
		end
	end
	return cache.uptime
end

-- refreshed every 15 min
local function weather()
	local now = os.time()
	if now - cache.weather_at >= 900 then
		cache.weather_at = now
		local url = "wttr.in/" .. (CITY:gsub(" ", "+")) .. "?format=%C+%t"
		local ok, success, out = pcall(wezterm.run_child_process, { "curl", "-fsm", "3", url })
		if ok and success and out:match("%d°[CF]%s*$") then
			cache.weather = (out:gsub("%s+$", ""):gsub("%s+", " "))
		end
	end
	return cache.weather
end

local function seg(fg, bg, text, bold)
	return {
		{ Foreground = { Color = fg } },
		{ Background = { Color = bg } },
		{ Attribute = { Intensity = bold and "Bold" or "Normal" } },
		{ Text = text },
		"ResetAttributes",
	}
end

local function append(dst, src)
	for _, e in ipairs(src) do
		table.insert(dst, e)
	end
end

wezterm.on("update-status", function(window, pane)
	local left, right = {}, {}

	local ws = window:active_workspace():gsub("^%l", string.upper)
	append(left, seg(C.black, C.purple, " " .. ws .. " ", true))
	local up = uptime()
	if up ~= "" then
		append(left, seg(C.fg, C.border, " ↑ " .. up .. " ", false))
	end
	table.insert(left, { Text = " " })
	window:set_left_status(wezterm.format(left))

	if window:active_key_table() == "prefix" then
		append(right, seg(C.black, C.purple, " ⌨ PREFIX ", true))
		table.insert(right, { Text = " " })
	end
	local w = weather()
	if w ~= "" then
		append(right, seg(C.fg, C.border, " " .. w .. " ", false))
	end
	append(right, seg(C.black, C.cyan, " " .. CITY .. " ", true))
	append(right, seg(C.black, C.purple, " " .. wezterm.strftime("%d %b %H:%M") .. " ", true))
	window:set_right_status(wezterm.format(right))
end)

wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
	local title = tab.tab_title
	if not title or #title == 0 then
		title = tab.active_pane.title
	end
	title = wezterm.truncate_right(title, math.max(max_width - 8, 4))
	local zoom = tab.active_pane.is_zoomed and " Z" or ""
	local text = " " .. (tab.tab_index + 1) .. " " .. title .. zoom .. " "
	if tab.is_active then
		return {
			{ Background = { Color = C.purple } },
			{ Foreground = { Color = C.black } },
			{ Attribute = { Intensity = "Bold" } },
			{ Text = text },
		}
	end
	return {
		{ Background = { Color = C.bg } },
		{ Foreground = { Color = C.dim } },
		{ Text = text },
	}
end)

-- On launch: restore the saved layout, then maximize
-- fills the screen but keeps the taskbar / menu bar, unlike fullscreen
wezterm.on("gui-startup", function(cmd)
	if resurrect then
		resurrect.state_manager.resurrect_on_gui_startup(cmd)
	end
	if #wezterm.mux.all_windows() == 0 then
		wezterm.mux.spawn_window(cmd or {})
	end
	for _, mux_win in ipairs(wezterm.mux.all_windows()) do
		local gui_win = mux_win:gui_window()
		if gui_win then
			gui_win:maximize()
		end
	end
end)

-- Fullscreen on Windows: hide the tab/status bar so only the pane shows
local HIDE_BARS_IN_FULLSCREEN = is_windows

wezterm.on("window-resized", function(window, pane)
	if not HIDE_BARS_IN_FULLSCREEN then
		return
	end
	local overrides = window:get_config_overrides() or {}
	local show_bar = not window:get_dimensions().is_full_screen
	if overrides.enable_tab_bar ~= show_bar then
		overrides.enable_tab_bar = show_bar
		window:set_config_overrides(overrides)
	end
end)

return config
