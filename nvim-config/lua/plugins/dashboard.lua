-- Branded start screen via snacks.nvim dashboard (ships with LazyVim).
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = table.concat({
            "",
            "  ███╗   ███╗ █████╗ ██╗   ██╗████████╗ ██╗   ██╗██╗███╗   ███╗",
            "  ████╗ ████║██╔══██╗██║   ██║╚══██╔══╝ ██║   ██║██║████╗ ████║",
            "  ██╔████╔██║███████║██║   ██║   ██║    ██║   ██║██║██╔████╔██║",
            "  ██║╚██╔╝██║██╔══██║██║   ██║   ██║    ╚██╗ ██╔╝██║██║╚██╔╝██║",
            "  ██║ ╚═╝ ██║██║  ██║╚██████╔╝   ██║     ╚████╔╝ ██║██║ ╚═╝ ██║",
            "  ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝    ╚═╝      ╚═══╝  ╚═╝╚═╝     ╚═╝",
            "",
            "        press  <space>  to see every shortcut  ·  󰚩  <space>C  Claude sessions",
            "",
          }, "\n"),
        },
      },
    },
  },
}
