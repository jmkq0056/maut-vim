-- Yazi — the blue terminal file manager — embedded as a floating file browser.
return {
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    dependencies = { "folke/snacks.nvim" },
    keys = {
      -- Yazi is the *popup* file manager. The persistent sidebar tree stays on
      -- <leader>e (Snacks explorer, LazyVim default) so it feels like VS Code.
      { "<leader>-", function() require("yazi").yazi() end, desc = "Yazi (browse from current file)" },
      { "<leader>fm", function() require("yazi").yazi() end, desc = "Yazi file manager" },
      { "<leader>fM", function() require("yazi").yazi(nil, vim.fn.getcwd()) end, desc = "Yazi at project root" },
    },
    opts = {
      open_for_directories = true, -- `nvim some/dir` opens Yazi instead of netrw
      floating_window_scaling_factor = 0.9,
      yazi_floating_window_border = "rounded",
      keymaps = {
        show_help = "<f1>", -- F1 inside Yazi lists every Yazi shortcut
      },
    },
  },
}
