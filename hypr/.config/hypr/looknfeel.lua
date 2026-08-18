-- Personal look'n'feel overrides.
-- https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
  general = {
    -- Remove the gap under the top bar; keep 10px on the other sides.
    -- Fields: top, right, bottom, left.
    gaps_out = { top = 0, right = 10, bottom = 10, left = 10 },
  },

  decoration = {
    -- Slightly rounded corners and a touch of transparency on unfocused windows.
    rounding = 4,
    inactive_opacity = 0.95,
  },
})
