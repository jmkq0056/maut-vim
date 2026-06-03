-- MautVim project manager: remembers folders you open (like an IDE's "recent
-- projects") and powers the welcome screen. No native dialog unless you ask to
-- browse for a new folder.

local M = {}

local function statefile()
  return vim.fn.stdpath("state") .. "/mautvim_projects.json"
end

-- Most-recent-first list of folders that still exist on disk.
function M.recents()
  local p = statefile()
  if vim.fn.filereadable(p) == 0 then
    return {}
  end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(p), "\n"))
  if not ok or type(data) ~= "table" then
    return {}
  end
  local out = {}
  for _, d in ipairs(data) do
    if type(d) == "string" and vim.fn.isdirectory(d) == 1 then
      out[#out + 1] = d
    end
  end
  return out
end

-- Push a folder to the front of the recents list (deduped, capped).
function M.record(dir)
  dir = vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")
  if vim.fn.isdirectory(dir) == 0 then
    return
  end
  local new = { dir }
  for _, d in ipairs(M.recents()) do
    if d ~= dir and #new < 15 then
      new[#new + 1] = d
    end
  end
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  vim.fn.writefile({ vim.json.encode(new) }, statefile())
end

-- Switch the editor into a project: cd, remember it, open the file tree.
function M.open(dir)
  if not dir or dir == "" or vim.fn.isdirectory(dir) == 0 then
    vim.notify("MautVim: not a folder: " .. tostring(dir), vim.log.levels.WARN)
    return
  end
  M.record(dir)
  vim.cmd("cd " .. vim.fn.fnameescape(dir))
  vim.schedule(function()
    pcall(function()
      Snacks.explorer()
    end)
    pcall(vim.cmd, "wincmd p")
    vim.notify("MautVim: opened " .. vim.fn.fnamemodify(dir, ":~"))
  end)
end

-- Browse for a new folder via the native macOS picker (only on demand).
function M.browse()
  local out = vim.fn.system([[osascript -e 'try
  POSIX path of (choose folder with prompt "MautVim — open a folder:")
on error
  return ""
end try']])
  out = (out or ""):gsub("%s+$", "")
  if out ~= "" then
    M.open(out)
  end
end

-- Pick from recent projects (falls back to browse if there are none).
function M.pick()
  local list = M.recents()
  if #list == 0 then
    M.browse()
    return
  end
  vim.ui.select(list, {
    prompt = "Recent projects",
    format_item = function(d)
      return vim.fn.fnamemodify(d, ":~")
    end,
  }, function(choice)
    if choice then
      M.open(choice)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("MautOpen", M.browse, { desc = "Open a folder (browse)" })
  vim.api.nvim_create_user_command("MautRecent", M.pick, { desc = "Open a recent project" })
  -- Remember a folder when MautVim is launched directly on one.
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      if vim.fn.argc() > 0 then
        local a = vim.fn.argv(0)
        if type(a) == "string" and vim.fn.isdirectory(a) == 1 then
          M.record(a)
        end
      else
        M.record(vim.fn.getcwd())
      end
    end,
  })
end

return M
