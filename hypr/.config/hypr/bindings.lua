-- Personal keybinding overrides (Omarchy "quattro" Lua config model).
-- Omarchy loads its own defaults first (see ~/.local/share/omarchy/default/hypr),
-- then this file, so only genuine overrides belong here.
-- View every active binding: omarchy menu keybindings --print

-- Free SUPER + P (Omarchy default: Pseudo window) so it reaches the focused
-- app instead, e.g. Ghostty's fuzzy switcher.
hl.unbind("SUPER + P")

-- macOS-style Cmd + Q to close the active window (Omarchy keeps SUPER + W too).
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- Speech-to-text dictation (toggle: press to record, press again to
-- transcribe + type).
o.bind("SUPER + ALT + D", "Dictate", "/home/arthur/.local/bin/dictate")

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
