-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Pin workspaces to monitors (this machine's dual 2560x1440 setup):
--   DP-1     (ASUS VG27AQ3A, primary)   -> workspaces 1-5
--   HDMI-A-1 (ViewSonic VX3276-QHD)     -> workspaces 6-10
for ws = 1, 5 do
  hl.workspace_rule({ workspace = tostring(ws), monitor = "DP-1", default = ws == 1 })
end
for ws = 6, 10 do
  hl.workspace_rule({ workspace = tostring(ws), monitor = "HDMI-A-1", default = ws == 6 })
end

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
