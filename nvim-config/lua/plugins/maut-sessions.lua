-- Loads the bundled maut-sessions.nvim plugin (lives next to this config).
return {
  {
    "maut-sessions.nvim",
    dir = vim.fn.stdpath("config") .. "/maut-sessions",
    name = "maut-sessions.nvim",
    lazy = false,
    config = function()
      require("maut-sessions").setup({})
    end,
    -- which-key shows these under the "Claude (sessions)" group.
    keys = {
      { "<leader>Cs", "<cmd>MautSessions<cr>", desc = "Browse Claude sessions" },
      { "<leader>Cr", "<cmd>MautResume<cr>", desc = "Resume latest Claude session" },
      { "<leader>Cn", "<cmd>MautNew<cr>", desc = "Start new Claude session" },
    },
  },
}
