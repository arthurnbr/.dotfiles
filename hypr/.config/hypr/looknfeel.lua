-- Personal look'n'feel overrides.
-- https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
  general = {
    -- Uniform gap all around, so the space under the top bar matches the
    -- screen-edge gap on the sides.
    gaps_out = 10,
  },

  decoration = {
    -- Slightly rounded corners and a touch of transparency on unfocused windows.
    rounding = 4,
    inactive_opacity = 0.95,
  },
})

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.
