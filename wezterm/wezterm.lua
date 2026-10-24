-- WezTerm: a minimal host for tmux. tmux owns sessions, panes, status and visuals.
local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find("windows") ~= nil
local is_mac = wezterm.target_triple:find("apple") ~= nil

-- Settings
local WSL_DISTRO = "Ubuntu-22.04"

-- Appearance
config.font = wezterm.font("JetBrains Mono")
config.font_size = is_windows and 15 or 19.0
config.color_scheme = "Tokyo Night"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.enable_tab_bar = false
config.enable_kitty_graphics = true
config.check_for_updates = false

-- macOS keyboard behavior (Alt works as Meta for nvim/tmux)
if is_mac then
	config.send_composed_key_when_left_alt_is_pressed = false
	config.send_composed_key_when_right_alt_is_pressed = true
end

-- Windows / WSL
if is_windows then
	local wanted = "WSL:" .. WSL_DISTRO
	local domains = wezterm.default_wsl_domains()
	local found = false

	for _, domain in ipairs(domains) do
		if domain.name == wanted then
			found = true
			break
		end
	end

	if found then
		config.default_domain = wanted
	elseif #domains > 0 then
		wezterm.log_warn("WSL distro " .. WSL_DISTRO .. " not found; using " .. domains[1].name)
		config.default_domain = domains[1].name
	else
		wezterm.log_warn("No WSL domains found. Using the default shell.")
	end

	config.launch_menu = {
		{
			label = "PowerShell",
			args = { "powershell.exe", "-NoLogo" },
		},
		{
			label = "Command Prompt",
			args = { "cmd.exe" },
		},
	}
end

-- Keys
config.keys = {}

if is_windows then
	-- Fullscreen shortcut
	table.insert(config.keys, { key = "F11", action = act.ToggleFullScreen })

	-- Ctrl+C copies a selection, otherwise sends Ctrl+C to the shell
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

	table.insert(config.keys, { key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") })
	table.insert(config.keys, { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") })
end

-- Start fullscreen on every platform
wezterm.on("gui-startup", function(cmd)
	local _, _, window = wezterm.mux.spawn_window(cmd or {})

	if window then
		local gui_window = window:gui_window()
		if gui_window then
			gui_window:toggle_fullscreen()
		end
	end
end)

return config
