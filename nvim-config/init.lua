-- MautVim — a Claude-Code-aware Neovim distribution.
-- Leader must be set before lazy.nvim loads any plugin.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Register the project manager early (defines :MautOpen/:MautRecent and the
-- recent-folders hook) — LazyVim defers config/autocmds.lua to VeryLazy, which
-- is too late for the VimEnter hook and the welcome-screen commands.
require("maut.projects").setup()

-- Route PDFs/images/Office files/etc. to their native macOS app instead of
-- showing raw bytes. Registered early so it's active before any file is read.
require("maut.external").setup()

require("config.lazy")
