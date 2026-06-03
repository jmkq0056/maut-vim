-- Reads Claude Code session transcripts and extracts the file-edit activity.
--
-- Claude Code writes one JSONL transcript per session at:
--   ~/.claude/projects/<project-slug>/<session-id>.jsonl
-- where <project-slug> is the absolute workspace path with non-alphanumerics
-- turned into dashes. Each line is a JSON object with a `type` field:
--   user | assistant | file-history-snapshot | summary | system | attachment | ...
--
-- The entries we care about:
--   * assistant.message.content[] items of {type="tool_use", name="Edit"|"Write"
--     |"MultiEdit", input.file_path} -> a file Claude changed.
--   * file-history-snapshot.snapshot.trackedFileBackups[absPath] =
--     {backupFileName="<hash>@vN", version} -> where the pre-edit backups live.

local M = {}

local uv = vim.uv or vim.loop
local EDIT_TOOLS = { Edit = true, Write = true, MultiEdit = true }

local function projects_root()
  return vim.fn.expand("~/.claude/projects")
end

-- First-pass slug: replace every run of non-alphanumeric chars with a single dash,
-- matching how Claude Code names the project directory for typical paths.
local function encode_slug(path)
  return (path:gsub("[^%w]+", "-"))
end

local function read_first_cwd(jsonl_path)
  local fh = io.open(jsonl_path, "r")
  if not fh then
    return nil
  end
  local cwd
  for _ = 1, 200 do -- only need an early line; transcripts put cwd on every user/assistant entry
    local line = fh:read("*l")
    if not line then
      break
    end
    local ok, obj = pcall(vim.json.decode, line)
    if ok and type(obj) == "table" and obj.cwd then
      cwd = obj.cwd
      break
    end
  end
  fh:close()
  return cwd
end

-- Find the ~/.claude/projects/<slug> directory for a workspace.
-- Tries the encoded slug first (fast path), then falls back to scanning every
-- project dir and matching the `cwd` recorded inside its transcripts (correct
-- regardless of how the slug was encoded).
function M.find_project_dir(cwd)
  cwd = cwd or vim.fn.getcwd()
  local root = projects_root()

  local candidate = root .. "/" .. encode_slug(cwd)
  if vim.fn.isdirectory(candidate) == 1 then
    return candidate
  end

  -- Fallback: scan and match recorded cwd.
  local entries = vim.fn.globpath(root, "*", false, true)
  for _, dir in ipairs(entries) do
    if vim.fn.isdirectory(dir) == 1 then
      local jsonls = vim.fn.globpath(dir, "*.jsonl", false, true)
      if #jsonls > 0 then
        local recorded = read_first_cwd(jsonls[1])
        if recorded == cwd then
          return dir
        end
      end
    end
  end
  return nil
end

-- Normalize a user message's content into a short one-line summary string.
local function content_to_text(content)
  if type(content) == "string" then
    return content
  end
  if type(content) == "table" then
    for _, part in ipairs(content) do
      if type(part) == "table" and part.type == "text" and type(part.text) == "string" then
        return part.text
      end
    end
  end
  return nil
end

local function one_line(s)
  if not s then
    return nil
  end
  s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

-- Parse a single transcript file into a session table.
function M.parse_session(path)
  local id = vim.fn.fnamemodify(path, ":t:r")
  local stat = uv.fs_stat(path)
  local session = {
    id = id,
    path = path,
    cwd = nil,
    summary = nil, -- human title: explicit `summary` line if present, else first user prompt
    first_prompt = nil,
    mtime = stat and stat.mtime.sec or 0,
    git_branch = nil,
    files = {}, -- ordered: { path, rel, count, last_ts, created }
    files_index = {}, -- abs -> files entry
    backups = {}, -- abs -> { backupFileName, version }
  }

  local lines = vim.fn.readfile(path)
  for _, line in ipairs(lines) do
    if line ~= "" then
      local ok, obj = pcall(vim.json.decode, line)
      if ok and type(obj) == "table" then
        local t = obj.type

        if obj.cwd and not session.cwd then
          session.cwd = obj.cwd
        end
        if obj.gitBranch and not session.git_branch then
          session.git_branch = obj.gitBranch
        end

        if t == "summary" and type(obj.summary) == "string" then
          session.summary = one_line(obj.summary)
        elseif t == "user" and obj.message then
          if not session.first_prompt then
            local text = one_line(content_to_text(obj.message.content))
            -- Skip command-wrapper / caveat noise for the title when possible.
            if text and not text:match("^<command") and not text:match("^Caveat:") then
              session.first_prompt = text
            elseif text and not session.first_prompt then
              session.first_prompt = text
            end
          end
        elseif t == "assistant" and obj.message and type(obj.message.content) == "table" then
          for _, c in ipairs(obj.message.content) do
            if type(c) == "table" and c.type == "tool_use" and EDIT_TOOLS[c.name] then
              local fp = c.input and c.input.file_path
              if type(fp) == "string" and fp ~= "" then
                local entry = session.files_index[fp]
                if not entry then
                  entry = { path = fp, count = 0, last_ts = obj.timestamp, created = (c.name == "Write") }
                  session.files_index[fp] = entry
                  table.insert(session.files, entry)
                end
                entry.count = entry.count + 1
                entry.last_ts = obj.timestamp or entry.last_ts
                -- A file is only "created" if its very first action was a Write.
                if entry.count == 1 and c.name ~= "Write" then
                  entry.created = false
                end
              end
            end
          end
        elseif t == "file-history-snapshot" then
          local tfb = obj.snapshot and obj.snapshot.trackedFileBackups
          if type(tfb) == "table" then
            for abs, info in pairs(tfb) do
              -- JSON null decodes to vim.NIL (userdata, which is truthy in Lua),
              -- so require an actual string before trusting the field.
              if type(info) == "table" and type(info.backupFileName) == "string" then
                session.backups[abs] = {
                  backupFileName = info.backupFileName,
                  version = info.version,
                }
              end
            end
          end
        end
      end
    end
  end

  session.summary = session.summary or session.first_prompt or "(no prompt recorded)"

  -- Compute paths relative to the session cwd for display.
  local base = session.cwd
  for _, e in ipairs(session.files) do
    if base and e.path:sub(1, #base + 1) == base .. "/" then
      e.rel = e.path:sub(#base + 2)
      e.in_workspace = true
    else
      e.rel = e.path
      e.in_workspace = false
    end
  end

  -- Workspace files first, then by most-recently edited.
  table.sort(session.files, function(a, b)
    if a.in_workspace ~= b.in_workspace then
      return a.in_workspace
    end
    return (a.last_ts or "") > (b.last_ts or "")
  end)

  return session
end

-- List all sessions for a workspace, newest activity first.
function M.list_sessions(cwd)
  local dir = M.find_project_dir(cwd)
  if not dir then
    return {}, nil
  end
  local jsonls = vim.fn.globpath(dir, "*.jsonl", false, true)
  local sessions = {}
  for _, p in ipairs(jsonls) do
    local ok, s = pcall(M.parse_session, p)
    if ok and s then
      table.insert(sessions, s)
    end
  end
  table.sort(sessions, function(a, b)
    return a.mtime > b.mtime
  end)
  return sessions, dir
end

return M
