-- Branded IDE-style welcome screen via snacks.nvim dashboard.
-- Lists recent projects (press the number to open) + common actions.
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
          }, "\n"),
          -- Action keys (also pressable from the welcome screen).
          keys = {
            { icon = " ", key = "o", desc = "Open Folder…", action = function() require("maut.projects").browse() end },
            { icon = " ", key = "r", desc = "Recent Projects", action = function() require("maut.projects").pick() end },
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = "󰚩 ", key = "C", desc = "Claude Sessions", action = ":MautSessions" },
            { icon = " ", key = "l", desc = "Plugins (Lazy)", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { text = "  press <space> anytime to see every shortcut", hl = "comment", padding = 1 },
          { title = "Open", padding = 1 },
          { section = "keys", gap = 1, padding = 1 },
          { title = "Recent Projects", padding = 1 },
          function()
            local items = {}
            for i, dir in ipairs(require("maut.projects").recents()) do
              if i > 8 then
                break
              end
              items[#items + 1] = {
                icon = " ",
                key = tostring(i),
                desc = vim.fn.fnamemodify(dir, ":~"),
                action = function()
                  require("maut.projects").open(dir)
                end,
              }
            end
            if #items == 0 then
              items[1] = { text = "    no recent projects yet — press o to open a folder", hl = "comment" }
            end
            return items
          end,
          -- Friendly footer instead of snacks' "loaded N/M plugins" (the N/M is
          -- normal lazy-loading, but it reads like something's missing).
          function()
            local ok, stats = pcall(function()
              return require("lazy").stats()
            end)
            local ms = ok and math.floor((stats.startuptime or 0) + 0.5) or 0
            return {
              {
                align = "center",
                padding = 1,
                text = "⚡ ready in " .. ms .. " ms  ·  plugins load instantly as you use them",
                hl = "footer",
              },
            }
          end,
        },
      },
    },
  },
}
