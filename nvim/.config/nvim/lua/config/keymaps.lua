-- Keymaps loaded on VeryLazy. LazyVim defaults are kept; this file only
-- adds extras and a few aliases tailored to the eduvia workflow.
--
-- Cheat sheet (the most useful ones — the rest is in the README):
--   <leader><space>   smart fuzzy file picker (root-aware)
--   <leader>/         live grep across the project
--   <leader>e         toggle Neo-tree explorer
--   gd / gr / K       LSP definition / references / hover
--   <C-o> / <C-i>     jumplist back / forward (the inverse of `gd`)
--   s {char}{char}    flash teleport (cursor jump)

local map = vim.keymap.set

-- Yank the relative path of the current buffer. Handy for pasting into
-- Claude / chat prompts ("look at app/models/user.rb:42").
map("n", "<leader>fy", function()
  local path = vim.fn.expand("%:.")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Yank relative path" })

-- Same with line number appended (cursor:line).
map("n", "<leader>fY", function()
  local path = vim.fn.expand("%:.") .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Yank relative path:line" })

-- Open file in horizontal / vertical split via LSP definition.
map("n", "<leader>gd", function()
  vim.cmd("vsplit")
  vim.lsp.buf.definition()
end, { desc = "LSP definition (vsplit)" })

-- Quick way back to the previous cursor position. Same as <C-o> but
-- discoverable through which-key.
map("n", "<leader>bb", "<C-o>", { desc = "Jump back (prev cursor)" })
map("n", "<leader>bf", "<C-i>", { desc = "Jump forward" })

-- Repeat the last `:` command — saves a keystroke vs. `:<Up><CR>`.
map("n", "<leader>;", "@:", { desc = "Repeat last : command" })

-- Toggle "scratch" terminal at the project root, mirroring the user's
-- tmux Alt+G popup pattern.
map("n", "<leader>tt", function()
  Snacks.terminal()
end, { desc = "Toggle terminal (root)" })
