-- which-key: the live shortcut cheatsheet. This is the headline beginner feature —
-- press a prefix (e.g. <space>) and a menu of every next key + description pops up.
return {
  {
    "folke/which-key.nvim",
    opts = {
      preset = "helix", -- modern centered layout that's easy to read
      delay = 250, -- ms before the popup appears
      icons = {
        mappings = true,
        keys = {}, -- use defaults; Nerd Font glyphs render the keycaps
      },
      spec = {
        { "<leader>C", group = "Claude (sessions)", icon = "󰚩" },
      },
      -- Show a friendly notice if the help key is pressed.
      win = { border = "rounded" },
    },
  },
}
