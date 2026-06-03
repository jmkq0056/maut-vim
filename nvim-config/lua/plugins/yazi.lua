-- Yazi — the blue terminal file manager — embedded as a floating file browser.
return {
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    dependencies = { "folke/snacks.nvim" },
    keys = {
      { "<leader>-", function() require("yazi").yazi() end, desc = "Yazi (browse from current file)" },
      { "<leader>e", function() require("yazi").yazi() end, desc = "File browser (Yazi)" },
      { "<leader>E", function() require("yazi").yazi(nil, vim.fn.getcwd()) end, desc = "File browser at project root" },
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
