-- The "MAUT · CLAUDE SESSIONS" side panel: a file-centric view of what Claude
-- changed, per session, with diff/undo against the session-start backups.

local parser = require("maut-sessions.parser")
local backup = require("maut-sessions.backup")

local M = {}
local NS = vim.api.nvim_create_namespace("maut-sessions")

local state = {
  buf = nil,
  win = nil,
  sessions = {},
  dir = nil,
  cwd = nil,
  expanded = {},
  line_map = {},
}

-- ── helpers ───────────────────────────────────────────────────────────────
local function timeago(sec)
  local d = os.time() - sec
  if d < 0 then
    d = 0
  end
  if d < 60 then
    return d .. "s ago"
  elseif d < 3600 then
    return math.floor(d / 60) .. "m ago"
  elseif d < 86400 then
    return math.floor(d / 3600) .. "h ago"
  else
    return math.floor(d / 86400) .. "d ago"
  end
end

local function truncate(s, n)
  if vim.fn.strchars(s) > n then
    return vim.fn.strcharpart(s, 0, n - 1) .. "…"
  end
  return s
end

-- Build a line from {text, hlgroup} segments, tracking byte columns.
local function seg(parts)
  local text, hls = "", {}
  for _, p in ipairs(parts) do
    local start = #text
    text = text .. p[1]
    if p[2] then
      table.insert(hls, { start, #text, p[2] })
    end
  end
  return text, hls
end

local function setup_highlights()
  local link = function(name, to)
    vim.api.nvim_set_hl(0, name, { link = to, default = true })
  end
  link("MautSessionsTitle", "Title")
  link("MautSessionsMeta", "Comment")
  link("MautSessionsId", "NonText")
  link("MautSessionsExpanded", "Function")
  link("MautSessionsFile", "Normal")
  link("MautSessionsExtern", "NonText")
  link("MautSessionsNew", "DiagnosticOk")
  link("MautSessionsCount", "Comment")
  link("MautSessionsHint", "NonText")
end

-- ── render ──────────────────────────────────────────────────────────────────
function M.render()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  local lines, hls, line_map = {}, {}, {}
  local function add(text, segs, row)
    table.insert(lines, text)
    local ln = #lines - 1
    if segs then
      for _, h in ipairs(segs) do
        table.insert(hls, { ln, h[1], h[2], h[3] })
      end
    end
    if row then
      line_map[ln] = row
    end
  end
  local function addseg(parts, row)
    local text, segs = seg(parts)
    add(text, segs, row)
  end

  addseg({ { "  MAUT · CLAUDE SESSIONS", "MautSessionsTitle" } })
  local where = state.cwd and vim.fn.fnamemodify(state.cwd, ":~") or "?"
  addseg({ { "  " .. where, "MautSessionsMeta" } })
  addseg({ { string.rep("─", 54), "MautSessionsId" } })

  if not state.dir or #state.sessions == 0 then
    add("")
    addseg({ { "  No Claude Code sessions found for this folder.", "MautSessionsMeta" } })
    add("")
    addseg({ { "  Start one with  ", "MautSessionsHint" }, { "<space>Cn", "MautSessionsExpanded" } })
    addseg({ { "  or resume with  ", "MautSessionsHint" }, { "<space>Cr", "MautSessionsExpanded" } })
  else
    for i, s in ipairs(state.sessions) do
      local expanded = state.expanded[s.id]
      local arrow = expanded and "▾" or "▸"
      local n = #s.files
      local headline = string.format(
        "%s %s · %d file%s · ",
        arrow,
        timeago(s.mtime),
        n,
        n == 1 and "" or "s"
      )
      addseg({
        { " " .. headline, expanded and "MautSessionsExpanded" or "MautSessionsFile" },
        { '"' .. truncate(s.summary, 40) .. '"', "MautSessionsMeta" },
        { "  [" .. s.id:sub(1, 7) .. "]", "MautSessionsId" },
      }, { kind = "session", session = s, index = i })

      if expanded then
        if n == 0 then
          addseg({ { "       (no file edits in this session)", "MautSessionsMeta" } }, { kind = "empty" })
        else
          for _, e in ipairs(s.files) do
            local icon = e.created and "" or ""
            local namehl = e.in_workspace and "MautSessionsFile" or "MautSessionsExtern"
            local cnt = e.created and "write" or (e.count == 1 and "1 edit" or (e.count .. " edits"))
            local parts = {
              { "     " .. icon .. " ", "MautSessionsMeta" },
              { e.rel, namehl },
            }
            if e.created then
              table.insert(parts, { "  (new)", "MautSessionsNew" })
            end
            table.insert(parts, { "   ", "MautSessionsMeta" })
            table.insert(parts, { cnt, "MautSessionsCount" })
            addseg(parts, { kind = "file", session = s, entry = e })
          end
        end
      end
    end
    add("")
    addseg({ { "  <cr>", "MautSessionsExpanded" }, { " open/toggle  ", "MautSessionsHint" }, { "d", "MautSessionsExpanded" }, { " diff  ", "MautSessionsHint" }, { "u", "MautSessionsExpanded" }, { " undo  ", "MautSessionsHint" }, { "r", "MautSessionsExpanded" }, { " refresh  ", "MautSessionsHint" }, { "q", "MautSessionsExpanded" }, { " close", "MautSessionsHint" } })
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)
  for _, h in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(state.buf, NS, h[4], h[1], h[2], h[3])
  end
  state.line_map = line_map
end

-- ── actions ───────────────────────────────────────────────────────────────
local function row_under_cursor()
  local ln = vim.api.nvim_win_get_cursor(0)[1] - 1
  return state.line_map[ln]
end

function M.open_file(abs)
  local target
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if w ~= state.win then
      target = w
      break
    end
  end
  if target then
    vim.api.nvim_set_current_win(target)
  else
    vim.cmd("wincmd p")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(abs))
end

function M.diff_file(session, abs)
  local lines = backup.read_backup_lines(session, abs)
  if not lines then
    vim.notify("maut-sessions: no session-start backup for this file (created mid-session or pruned).", vim.log.levels.WARN)
    return
  end
  vim.cmd("tabedit " .. vim.fn.fnameescape(abs))
  vim.cmd("diffthis")
  vim.cmd("leftabove vnew")
  local b = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  vim.bo[b].buftype = "nofile"
  vim.bo[b].bufhidden = "wipe"
  vim.bo[b].swapfile = false
  local ft = vim.filetype.match({ filename = abs })
  if ft then
    vim.bo[b].filetype = ft
  end
  vim.bo[b].modifiable = false
  pcall(vim.api.nvim_buf_set_name, b, "session-start://" .. vim.fn.fnamemodify(abs, ":t"))
  vim.cmd("diffthis")
end

function M.undo_file(session, entry)
  local abs = entry.path
  if backup.has_backup(session, abs) then
    local choice = vim.fn.confirm(
      ("Restore this file to its state at the START of the session?\n\n%s\n\nThis OVERWRITES the current contents (including edits you made yourself)."):format(abs),
      "&Restore\n&Cancel",
      2
    )
    if choice == 1 then
      local ok, err = backup.restore_v1(session, abs)
      if ok then
        vim.notify("maut-sessions: restored " .. vim.fn.fnamemodify(abs, ":t"))
      else
        vim.notify("maut-sessions: restore failed — " .. err, vim.log.levels.ERROR)
      end
    end
  elseif entry.created then
    local choice = vim.fn.confirm(
      ("This file was CREATED during the session:\n\n%s\n\nThere is no earlier version. Delete it?"):format(abs),
      "&Delete\n&Cancel",
      2
    )
    if choice == 1 then
      local ok, err = backup.delete_created(abs)
      if ok then
        vim.notify("maut-sessions: deleted " .. vim.fn.fnamemodify(abs, ":t"))
        M.refresh()
      else
        vim.notify("maut-sessions: delete failed — " .. err, vim.log.levels.ERROR)
      end
    end
  else
    vim.notify("maut-sessions: no session-start backup available for this file.", vim.log.levels.WARN)
  end
end

function M.on_enter()
  local row = row_under_cursor()
  if not row then
    return
  end
  if row.kind == "session" then
    state.expanded[row.session.id] = not state.expanded[row.session.id]
    M.render()
  elseif row.kind == "file" then
    M.open_file(row.entry.path)
  end
end

function M.show_help()
  vim.notify(table.concat({
    "MAUT · CLAUDE SESSIONS — keys",
    "  <cr> / o   open file, or expand/collapse a session",
    "  d          diff the file against its session-start state",
    "  u          undo the file back to its session-start state",
    "  r          refresh the list",
    "  q          close the panel",
    "  g?         this help",
  }, "\n"), vim.log.levels.INFO, { title = "maut-sessions" })
end

-- ── window/buffer lifecycle ─────────────────────────────────────────────────
function M.is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

function M.set_keymaps(buf)
  local function km(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  km("<cr>", M.on_enter, "Open / toggle")
  km("o", M.on_enter, "Open / toggle")
  km("d", function()
    local r = row_under_cursor()
    if r and r.kind == "file" then
      M.diff_file(r.session, r.entry.path)
    end
  end, "Diff vs session start")
  km("u", function()
    local r = row_under_cursor()
    if r and r.kind == "file" then
      M.undo_file(r.session, r.entry)
    end
  end, "Undo to session start")
  km("r", M.refresh, "Refresh")
  km("q", M.close, "Close")
  km("g?", M.show_help, "Help")
end

local function ensure_buf()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "mautsessions"
  pcall(vim.api.nvim_buf_set_name, buf, "MautSessions")
  M.set_keymaps(buf)
  state.buf = buf
  return buf
end

function M.refresh()
  state.cwd = vim.fn.getcwd()
  state.sessions, state.dir = parser.list_sessions(state.cwd)
  if next(state.expanded) == nil and state.sessions[1] then
    state.expanded[state.sessions[1].id] = true
  end
  M.render()
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

function M.open()
  setup_highlights()
  state.cwd = vim.fn.getcwd()
  state.sessions, state.dir = parser.list_sessions(state.cwd)
  if next(state.expanded) == nil and state.sessions[1] then
    state.expanded[state.sessions[1].id] = true
  end
  local buf = ensure_buf()
  if not M.is_open() then
    vim.cmd("botright vsplit")
    state.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(state.win, buf)
    vim.api.nvim_win_set_width(state.win, 56)
    local wo = vim.wo[state.win]
    wo.number = false
    wo.relativenumber = false
    wo.wrap = false
    wo.cursorline = true
    wo.signcolumn = "no"
    wo.foldcolumn = "0"
    wo.winfixwidth = true
  else
    vim.api.nvim_set_current_win(state.win)
  end
  M.render()
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

return M
