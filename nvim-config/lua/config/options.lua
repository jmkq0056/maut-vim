-- Auto-loaded by LazyVim before plugins start.
-- Tuned for newcomers: absolute line numbers, mouse on, save-prompts instead of errors.
local opt = vim.opt

opt.relativenumber = false -- absolute numbers are easier to reason about when learning
opt.number = true
opt.mouse = "a" -- full mouse support (click, scroll, select) — training wheels that never hurt
opt.wrap = false
opt.scrolloff = 8 -- keep some context above/below the cursor
opt.confirm = true -- :q with unsaved changes asks to save instead of throwing an error
opt.clipboard = "unnamedplus" -- yank/paste shares the macOS system clipboard
opt.termguicolors = true
opt.signcolumn = "yes"

-- Friendlier which-key: pop the shortcut menu up quickly after pressing a prefix.
vim.o.timeout = true
vim.o.timeoutlen = 350
