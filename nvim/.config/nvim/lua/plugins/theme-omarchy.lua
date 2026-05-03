-- Optional: hot-reload Omarchy's current theme when present. On machines
-- without Omarchy, this file is a no-op so the tokyonight default kicks
-- in cleanly (no broken require, no error popup).

local omarchy_theme = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")
if vim.fn.filereadable(omarchy_theme) == 0 then
  return {}
end

return dofile(omarchy_theme)
