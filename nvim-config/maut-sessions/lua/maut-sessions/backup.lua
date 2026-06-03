-- Resolves and applies Claude Code's per-session file backups.
--
-- Claude stores the raw pre-edit bytes of every tracked file at:
--   ~/.claude/file-history/<session-id>/<hash>@v<N>
-- `@v1` is the state at the very start of the session. The transcript's
-- file-history-snapshot entries give us a `<hash>@vN` for each path; we strip
-- the version suffix and ask for `@v1` to get the original.

local M = {}

local uv = vim.uv or vim.loop

local function history_dir(session_id)
  return vim.fn.expand("~/.claude/file-history/" .. session_id)
end

-- Absolute path to the @v1 (session-start) backup for `abs`, or nil if there
-- isn't one (file created mid-session, or backups were pruned).
function M.v1_backup_path(session, abs)
  local info = session.backups[abs]
  if not info or type(info.backupFileName) ~= "string" then
    return nil
  end
  local hash = info.backupFileName:gsub("@v%d+$", "")
  local p = history_dir(session.id) .. "/" .. hash .. "@v1"
  if vim.fn.filereadable(p) == 1 then
    return p
  end
  return nil
end

-- Does this session have a usable backup for the file?
function M.has_backup(session, abs)
  return M.v1_backup_path(session, abs) ~= nil
end

-- Reload any loaded buffer pointing at `abs` so the editor reflects disk.
local function reload_buffers(abs)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == abs then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent! checktime")
        vim.cmd("silent! edit")
      end)
    end
  end
end

-- Restore `abs` to its session-start contents. Returns ok, err.
function M.restore_v1(session, abs)
  local v1 = M.v1_backup_path(session, abs)
  if not v1 then
    return false, "no session-start backup available"
  end
  local ok, err = uv.fs_copyfile(v1, abs)
  if not ok then
    return false, tostring(err)
  end
  reload_buffers(abs)
  return true
end

-- Delete a file that was created during the session. Returns ok, err.
function M.delete_created(abs)
  local ok, err = os.remove(abs)
  if not ok then
    return false, tostring(err)
  end
  -- Wipe any buffer that was showing it.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == abs then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  return true
end

-- Read backup bytes as a list of lines (for the diff view).
function M.read_backup_lines(session, abs)
  local v1 = M.v1_backup_path(session, abs)
  if not v1 then
    return nil
  end
  return vim.fn.readfile(v1)
end

return M
