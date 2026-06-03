-- Inline image & PDF rendering inside the editor (via kitty's graphics protocol).
-- Opening a .png/.jpg/.pdf/.svg shows the actual picture, not raw bytes.
-- Requires ImageMagick (+ Ghostscript for PDF) on PATH — MautVim.app bundles a
-- permissive ImageMagick policy and adds Homebrew to PATH so this works.
return {
  {
    "folke/snacks.nvim",
    opts = {
      image = {
        enabled = true,
        doc = { enabled = true, inline = true, float = true },
        -- Inline rendering only for real images — a quick glance at a picture,
        -- then close with <leader>x. PDFs are NOT here: a PDF image overlays the
        -- editor UI (hiding which-key/cmdline) and can't page/scroll, so PDFs
        -- open in Preview instead (see lua/maut/external.lua).
        formats = { "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "heic", "avif", "svg", "icns" },
      },
    },
  },
}
