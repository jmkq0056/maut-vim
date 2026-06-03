-- Open binary / document files (PDF, images, Office docs, archives, media) in
-- their native macOS app instead of dumping raw bytes into the editor.
-- This is the Neovim equivalent of maut-code's "open external" behavior.

local M = {}

-- File types that can't be rendered inline (images/PDFs are handled by
-- snacks.image — see lua/plugins/image.lua). These open in their native app.
local PATTERNS = {
  "*.docx", "*.doc", "*.xlsx", "*.xls", "*.pptx", "*.ppt", "*.odt", "*.pages", "*.numbers", "*.key",
  "*.zip", "*.tar", "*.gz", "*.tgz", "*.7z", "*.rar", "*.dmg", "*.pkg",
  "*.mp4", "*.mov", "*.m4v", "*.avi", "*.mkv", "*.webm", "*.mp3", "*.m4a", "*.wav", "*.flac",
}

function M.setup()
  vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = PATTERNS,
    callback = function(ev)
      local file = ev.file
      local buf = ev.buf

      -- Hand the file to the OS (Preview, Quick Look app, etc.).
      if not vim.env.MAUT_TEST then
        vim.schedule(function()
          pcall(vim.ui.open, file)
        end)
      end

      -- Replace the buffer with a friendly note instead of binary bytes.
      vim.bo[buf].buftype = "nofile"
      vim.bo[buf].swapfile = false
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "",
        "   " .. vim.fn.fnamemodify(file, ":t"),
        "",
        "  This is a binary / document file — MautVim opened it in its",
        "  default macOS app (PDFs in Preview, images in Preview, etc.).",
        "",
        "  A terminal editor can't render these as text.",
        "",
        "  q          close this buffer",
        "  <leader>fm preview it inside the editor with Yazi instead",
      })
      vim.bo[buf].modifiable = false
      vim.bo[buf].modified = false
      vim.keymap.set("n", "q", "<cmd>bdelete<cr>", { buffer = buf, nowait = true, silent = true })
    end,
  })
end

return M
