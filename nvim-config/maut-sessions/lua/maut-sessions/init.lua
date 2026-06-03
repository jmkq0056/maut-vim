-- maut-sessions.nvim — track and act on your Claude Code sessions from Neovim.
--
-- Commands:
--   :MautSessions   toggle the session/activity panel for the current project
--   :MautResume     open a terminal and resume the latest Claude session here
--   :MautNew        open a terminal and start a fresh Claude session here
--
-- Inspired by the maut-code "maut-activity" sidebar, rebuilt for Neovim.

local M = {}

M.config = {
  -- The launch command. `claude --dangerously-skip-permissions` matches the
  -- maut-code convention; portable to any machine with the Claude Code CLI.
  claude_cmd = "claude --dangerously-skip-permissions",
  -- Terminal split height for resume/new.
  term_height = 18,
}

local function open_claude_terminal(extra)
  local cmd = M.config.claude_cmd .. (extra and (" " .. extra) or "")
  vim.cmd("botright split")
  vim.cmd("resize " .. M.config.term_height)
  vim.cmd("terminal " .. cmd)
  vim.cmd("startinsert")
end

function M.resume()
  open_claude_terminal("--continue")
end

function M.new_session()
  open_claude_terminal(nil)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.api.nvim_create_user_command("MautSessions", function()
    require("maut-sessions.ui").toggle()
  end, { desc = "Toggle the Claude sessions panel" })

  vim.api.nvim_create_user_command("MautResume", function()
    M.resume()
  end, { desc = "Resume the latest Claude session in this folder" })

  vim.api.nvim_create_user_command("MautNew", function()
    M.new_session()
  end, { desc = "Start a new Claude session in this folder" })
end

return M
