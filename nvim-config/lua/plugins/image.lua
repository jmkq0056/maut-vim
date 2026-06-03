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
        -- Only formats we can reliably rasterize. Video is left to the native
        -- app (see lua/maut/external.lua) so we don't depend on ffmpeg.
        formats = { "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "heic", "avif", "svg", "pdf", "icns" },
      },
    },
  },
}
