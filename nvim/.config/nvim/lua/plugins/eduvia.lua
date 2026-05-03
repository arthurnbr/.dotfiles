-- Project-aware tweaks for the eduvia stack:
--   - Ruby:     prefer `standardrb` (the Gemfile has it) over plain rubocop.
--   - Vue/TS:   nothing custom — the LazyVim Vue + TypeScript extras already
--               wire up vue_ls + ts_ls + eslint + prettier.
--   - Snacks:   keep recent files / project picker tuned to monorepo roots.

return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.ruby = { "standardrb" }
      opts.formatters_by_ft.eruby = { "standardrb" }
      return opts
    end,
  },

  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        ui_select = true,
      },
      explorer = { replace_netrw = true },
    },
  },

  -- Make `gd` open in the current window AND jump to the right column.
  -- LazyVim's default uses snacks picker — keep the picker for ambiguous
  -- cases but ensure single-result definitions are immediate.
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false }, -- noisy in Vue/TS — toggle with <leader>uh
    },
  },

  -- `flash.nvim` ships with LazyVim — these tweaks just make the labels
  -- a bit more visible against tokyonight.
  {
    "folke/flash.nvim",
    opts = {
      modes = {
        char = { jump_labels = true },
      },
      label = { rainbow = { enabled = true, shade = 5 } },
    },
  },
}
