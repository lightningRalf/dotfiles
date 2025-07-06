-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action

-- This will hold the configuration.
local config = wezterm.config_builder()

config.color_scheme = 'Cupertino (base16)'

local function create_shell_spawner(shell_path, env_name)
  return act.SpawnCommandInNewTab {
    domain = 'CurrentPaneDomain',
    args = { shell_path },
    set_environment_variables = {
      WEZTERM_ACTIVE_SHELL = env_name
    }
  }
end

-- WSL-specific optimizations
if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
  config.default_prog = {'wsl', '--cd', '~'}
end

-- Show which key table is active in the status area
wezterm.on('update-right-status', function(window, pane)
  local name = window:active_key_table()
  if name then
    name = 'TABLE: ' .. name
  end
  window:set_right_status(name or '')
end)

config.leader = { key = 'Space', mods = 'SHIFT|ALT' }
config.keys = {
  -- CTRL+SHIFT+Space, followed by 'r' will put us in resize-pane
  -- mode until we cancel that mode.
  {
    key = 'r',
    mods = 'LEADER',
    action = act.ActivateKeyTable {
      name = 'resize_pane',
      one_shot = false,
    },
  },

  -- Use standard key bindings
  { key = 'Backspace', mods = 'CTRL', action = act.SendKey { key = 'Backspace', mods = 'ALT' } },

  -- Standard copy/paste
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },

  -- Standard tab management
  { key = 't', mods = 'CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL', action = act.CloseCurrentTab{ confirm = true } },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane{ confirm = false } },
  { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },
  
  -- spawn_command_in_new_tab is a convenience function to spawn a new tab with a command.
  -- It is used to open new tabs with specific shells or applications.
  -- PowerShell
  { key = 'p', mods = 'SHIFT|ALT', action = create_shell_spawner('pwsh.exe', 'PowerShell') },
  { key = 'n', mods = 'SHIFT|ALT', action = create_shell_spawner('nu.exe', 'Nushell') },
  { key = 'g', mods = 'SHIFT|ALT', action = create_shell_spawner('C:\\Program Files\\Git\\bin\\bash.exe', 'GitBash') },


  -- tab navigation
  { key = 'LeftArrow', mods = 'SHIFT|ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 's', mods = 'SHIFT|ALT', action = act.ActivatePaneDirection 'Left' },

  { key = 'RightArrow', mods = 'SHIFT|ALT', action = act.ActivatePaneDirection 'Right' },
  { key = 'f', mods = 'SHIFT|ALT', action = act.ActivatePaneDirection 'Right' },

  { key = 'UpArrow', mods = 'SHIFT|ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'e', mods = 'SHIFT|ALT', action = act.ActivatePaneDirection 'Up' },

  { key = 'DownArrow', mods = 'SHIFT|ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'd', mods = 'SHIFT|ALT', action = act.ActivatePaneDirection 'Down' },

  -- Standard tab switching with Ctrl+1-9
  { key = '1', mods = 'CTRL', action = act.ActivateTab(0) },
  { key = '2', mods = 'CTRL', action = act.ActivateTab(1) },
  { key = '3', mods = 'CTRL', action = act.ActivateTab(2) },
  { key = '4', mods = 'CTRL', action = act.ActivateTab(3) },
  { key = '5', mods = 'CTRL', action = act.ActivateTab(4) },
  { key = '6', mods = 'CTRL', action = act.ActivateTab(5) },
  { key = '7', mods = 'CTRL', action = act.ActivateTab(6) },
  { key = '8', mods = 'CTRL', action = act.ActivateTab(7) },
  { key = '9', mods = 'CTRL', action = act.ActivateTab(8) },

  -- Pane splitting with standard shortcuts
  { key = 'h', mods = 'SHIFT|ALT', action = act.SplitHorizontal{ domain = 'CurrentPaneDomain' } },
  { key = 'v', mods = 'SHIFT|ALT', action = act.SplitVertical{ domain = 'CurrentPaneDomain' } },

  -- Font size adjustment
  { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
  { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
  { key = '0', mods = 'CTRL', action = act.ResetFontSize },

  -- Find
  { key = 'f', mods = 'CTRL', action = act.Search 'CurrentSelectionOrEmptyString' },
}


config.key_tables = {
  -- Defines the keys that are active in our resize-pane mode.
  -- Since we're likely to want to make multiple adjustments,
  -- we made the activation one_shot=false. We therefore need
  -- to define a key assignment for getting out of this mode.
  -- 'resize_pane' here corresponds to the name="resize_pane" in
  -- the key assignments above.
  resize_pane = {
    { key = 'LeftArrow', action = act.AdjustPaneSize { 'Left', 1 } },
    { key = 'h', action = act.AdjustPaneSize { 'Left', 1 } },

    { key = 'RightArrow', action = act.AdjustPaneSize { 'Right', 1 } },
    { key = 'l', action = act.AdjustPaneSize { 'Right', 1 } },

    { key = 'UpArrow', action = act.AdjustPaneSize { 'Up', 1 } },
    { key = 'k', action = act.AdjustPaneSize { 'Up', 1 } },

    { key = 'DownArrow', action = act.AdjustPaneSize { 'Down', 1 } },
    { key = 'j', action = act.AdjustPaneSize { 'Down', 1 } },

    -- Cancel the mode by pressing escape
    { key = 'Escape', action = 'PopKeyTable' },
  },

  -- Defines the keys that are active in our activate-pane mode.
  -- 'activate_pane' here corresponds to the name="activate_pane" in
  -- the key assignments above.
  --activate_pane = {

  --},
}

-- Standard selection behavior
-- config.selection_word_boundary = ' \t\n{}[]()"\\'

-- Enable standard mouse behavior
config.mouse_bindings = {
  -- Standard click and drag to select
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  -- Double-click to select word
  {
    event = { Up = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  -- Triple-click to select line
  {
    event = { Up = { streak = 3, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  -- Right-click to paste
  {
    event = { Up = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = act.PasteFrom 'Clipboard',
  },
}

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 28

-- or, changing the font size and color scheme.
config.font_size = 12
-- config.color_scheme = 'AdventureTime'

-- Finally, return the configuration to wezterm:
return config