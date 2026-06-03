-- Blue theme: tokyonight "night" (deep navy). Ships with LazyVim already.
return {
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night", -- deepest-blue variant
      transparent = false,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
