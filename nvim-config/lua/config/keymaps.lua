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
