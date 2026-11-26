-- Personal keybinding overrides (Omarchy "quattro" Lua config model).
-- Omarchy loads its own defaults first (see ~/.local/share/omarchy/default/hypr),
-- then this file, so only genuine overrides belong here.
-- View every active binding: omarchy menu keybindings --print

-- Free SUPER + P (Omarchy default: Pseudo window) so it reaches the focused
-- app instead, e.g. Ghostty's fuzzy switcher.
hl.unbind("SUPER + P")

-- Open Ghostty directly on SUPER + RETURN (Omarchy default: xdg-terminal-exec).
hl.unbind("SUPER + RETURN")
o.bind("SUPER + RETURN", "Terminal", "ghostty")

-- macOS-style Cmd + Q to close the active window (Omarchy keeps SUPER + W too).
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- Speech-to-text dictation via Voxtype (toggle: press to record, press
-- again to transcribe + type). Daemon: systemctl --user status voxtype.
o.bind("SUPER + ALT + D", "Dictate", "voxtype record toggle")

-- Activity monitor (btop) on SUPER + SHIFT + T
-- (Omarchy's own Activity binding is SUPER + CTRL + T).
o.bind("SUPER + SHIFT + T", "Activity", { tui = "btop" })

-- Use Typora on SUPER + SHIFT + W (overrides Omarchy's default Omawrite).
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })

-- Region screenshot straight to the clipboard on SUPER + SHIFT + S
-- (overrides Omarchy's default Google Maps web app on that key).
hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot region copy")

-- Floating scratchpad terminal (quake-style toggle) on SUPER + Z.
o.bind("SUPER + Z", "Floating terminal", "/home/arthur/.local/bin/floatterm-toggle")
o.window("org\\.omarchy\\.floatterm", { float = true })
o.window("org\\.omarchy\\.floatterm", { workspace = "special:floatterm" })
o.window("org\\.omarchy\\.floatterm", { size = { "(monitor_w*0.6)", "(monitor_h*0.6)" } })
o.window("org\\.omarchy\\.floatterm", { center = true })

-- Dictation keys from before Alt + Space and Right Alt became the defaults.
-- Remove these lines to give the keys back to applications.
if o.dictation_installed and o.dictation_installed() then
  o.bind("SUPER + CTRL + X", "Toggle dictation", "omarchy-dictation toggle")
  o.bind_hold("F9", "Start dictation (push-to-talk)", "omarchy-dictation start", "Stop dictation (push-to-talk)", "omarchy-dictation stop")
end

-- Wallpaper Engine dial (Omatrix) on SUPER + CTRL + SPACE
-- (overrides Omarchy's default Background switcher on that key).
hl.unbind("SUPER + CTRL + SPACE")
o.bind("SUPER + CTRL + SPACE", "Wallpaper Engine picker", "omarchy-we omatrix")
