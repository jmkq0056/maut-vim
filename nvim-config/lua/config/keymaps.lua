-- Auto-loaded by LazyVim. Extra beginner-friendly maps on top of the LazyVim defaults.
local map = vim.keymap.set

-- Ctrl-S saves from any mode, like every other editor on earth.
map({ "n", "i", "v" }, "<C-s>", "<cmd>silent! write<cr><esc>", { desc = "Save file" })

-- One key to see EVERY shortcut available right now (the whole point of MautVim).
map("n", "<leader>?", function()
  require("which-key").show({ global = true })
end, { desc = "Show ALL keybindings" })

-- <Esc> clears search highlight too.
map("n", "<Esc>", "<cmd>nohlsearch<cr><Esc>", { desc = "Clear search highlight" })

-- Back to the welcome / home screen.
map("n", "<leader>H", function()
  pcall(function()
    Snacks.dashboard()
  end)
end, { desc = "Home (welcome screen)" })

-- Open the current file in its real macOS app (e.g. a PDF in Preview, to
-- scroll/zoom/page through it properly).
map("n", "<leader>o", function()
  local f = vim.fn.expand("%:p")
  if f ~= "" then
    pcall(vim.ui.open, f)
  end
end, { desc = "Open current file in default app" })

-- Close the current file quickly (alias people expect).
map("n", "<leader>x", "<cmd>bdelete<cr>", { desc = "Close current file" })
