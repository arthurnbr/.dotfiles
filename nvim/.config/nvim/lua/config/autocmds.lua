-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost" }, {
  group = vim.api.nvim_create_augroup("autosave", { clear = true }),
  callback = function(event)
    local buf = event.buf
    if vim.bo[buf].buftype ~= "" then return end
    if not vim.bo[buf].modifiable or vim.bo[buf].readonly then return end
    if vim.api.nvim_buf_get_name(buf) == "" then return end
    if not vim.bo[buf].modified then return end
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent! lockmarks update")
    end)
  end,
})
