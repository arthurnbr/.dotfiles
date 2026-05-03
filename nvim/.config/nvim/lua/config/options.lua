-- Options are loaded before lazy.nvim startup. LazyVim defaults stay;
-- we only override what we want different.

-- Plain line numbers (the user prefers absolute over relative).
vim.opt.relativenumber = false

-- Keep some breathing room when scrolling — the cursor never glues to the
-- top/bottom of the window.
vim.opt.scrolloff = 6

-- Use system clipboard by default so yanks land in `+` (Wayland: wl-copy).
vim.opt.clipboard = "unnamedplus"

-- Persist undo history across sessions.
vim.opt.undofile = true

-- Faster CursorHold-driven LSP/which-key responses.
vim.opt.updatetime = 200
