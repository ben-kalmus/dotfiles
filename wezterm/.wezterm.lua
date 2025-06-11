-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 48

-- or, changing the font size and color scheme.
config.font_size = 13
config.font = wezterm.font("Fira Code")
config.color_scheme = "Tokyo Night Moon"

config.term = "screen-256color"
-- Finally, return the configuration to wezterm:
return config
