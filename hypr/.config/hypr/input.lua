-- Personal input overrides. Uncommented settings replace Omarchy's defaults.
-- https://wiki.hypr.land/Configuring/Basics/Variables/#input
hl.config({
  input = {
    -- French keyboard, CapsLock acts as the Compose key.
    kb_layout = "fr",
    kb_options = "compose:caps",

    -- Faster key repeat with a longer initial delay.
    repeat_rate = 40,
    repeat_delay = 600,

    -- Start with NumLock on.
    numlock_by_default = true,

    touchpad = {
      -- Natural (inverse) scrolling.
      natural_scroll = true,

      -- Tame scroll speed.
      scroll_factor = 0.4,
    },
  },
})
