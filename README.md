<div align="center">

# MautVim

**A blue, beginner-friendly Neovim distribution that teaches you its own shortcuts — and tracks your Claude Code sessions right inside the editor.**

LazyVim · Yazi · tokyonight · which-key · a custom `maut-sessions` plugin

</div>

---

## What you get

- **It teaches you the keys.** Powered by [which-key](https://github.com/folke/which-key.nvim): press `<space>` and pause — a menu of every shortcut and what it does pops up. You never memorize anything; you read and pick. Press `<space>?` to see *all* keybindings at once.
- **Blue everything.** [tokyonight](https://github.com/folke/tokyonight.nvim) "night" theme.
- **Yazi built in.** The blue terminal file browser, embedded as a floating picker. `<space>e` to open it; `F1` inside Yazi lists Yazi's own keys.
- **A full LazyVim base.** LSP, completion, fuzzy finding, git signs, treesitter, statusline, a start dashboard — all pre-wired and sane.
- **`maut-sessions` — the headline feature.** A side panel that reads Claude Code's own session transcripts and shows, per session, exactly which files Claude edited — with **diff** and **undo** back to how the file looked at the start of the session. Inspired by the `maut-activity` sidebar from [maut-code](https://github.com/jmkq0056/maut-code), rebuilt for Neovim.

## The `maut-sessions` panel

| Key | Command | What it does |
|----|---------|--------------|
| `<space>Cs` | `:MautSessions` | Toggle the Claude sessions panel for the current project |
| `<space>Cr` | `:MautResume` | Open a terminal and **resume** the latest Claude session here (`claude --continue`) |
| `<space>Cn` | `:MautNew` | Open a terminal and start a **fresh** Claude session here |

Inside the panel:

```
  MAUT · CLAUDE SESSIONS
  ~/Developer/my-project
 ──────────────────────────────────────────────────────
 ▾ 2m ago · 3 files · "fix the parser bug"           [3c20979]
      lua/parser.lua                          3 edits
      README.md  (new)                        write
 ▸ 1h ago · 2 files · "add the dashboard"            [a1b2c3d]
```

| Key | Action |
|----|--------|
| `<cr>` / `o` | Open the file, or expand/collapse a session |
| `d` | **Diff** the file against its state at the start of the session |
| `u` | **Undo** the file back to its session-start state (or delete it, if Claude created it) |
| `r` | Refresh |
| `q` | Close |
| `g?` | Help |

### How it works

Claude Code writes a JSONL transcript per session to
`~/.claude/projects/<project-slug>/<session-id>.jsonl`, and snapshots the
pre-edit bytes of every file it touches to
`~/.claude/file-history/<session-id>/<hash>@v<N>`. `maut-sessions` parses the
transcript for `Edit`/`Write`/`MultiEdit` tool calls (ignoring reads, greps,
bash, etc.), groups them by file, and uses the `@v1` backups to power diff/undo.
Nothing is sent anywhere — it only reads files Claude already wrote to your disk.

## Install

### Option A — the app (recommended for sharing)

Download `MautVim-<version>.dmg` from the [Releases](https://github.com/jmkq0056/maut-vim/releases)
page, open it, drag **MautVim** to Applications, and launch it. A folder picker
appears (editor-style "Open Folder") — choose a project, and MautVim opens it.

Everything is bundled — nothing else to install:

- **[kitty](https://sw.kovidgoyal.net/kitty/)**, a fast GPU terminal, so image
  previews, truecolor, and every key combo actually work (the system Terminal
  supports none of those well)
- `nvim`, `yazi`, `rg`, `fd`, `fzf`, `lazygit`, the Neovim runtime, all plugins,
  and the JetBrains Mono Nerd Font

> The first time, macOS Gatekeeper may warn that the app is from an
> unidentified developer (it's ad-hoc signed). Right-click → **Open**, or run
> `xattr -dr com.apple.quarantine /Applications/MautVim.app`.
>
> Resume/New Claude sessions require the [Claude Code CLI](https://claude.com/claude-code)
> on your `PATH`. Treesitter language parsers download on first file open
> (needs internet once).

### Option B — just the config

```bash
git clone https://github.com/jmkq0056/maut-vim ~/maut-vim
NVIM_APPNAME=mautvim cp -R ~/maut-vim/nvim-config ~/.config/mautvim
NVIM_APPNAME=mautvim nvim   # first launch installs plugins
```

This keeps MautVim isolated from any existing `~/.config/nvim`.

## Build it yourself

```bash
# 1. install plugins into the isolated profile
cp -R nvim-config ~/.config/mautvim
NVIM_APPNAME=mautvim nvim --headless "+Lazy! sync" +qa

# 2. assemble the .app (bundles binaries + plugins)
./scripts/build-app.sh 0.1.0

# 3. sign it (ad-hoc by default, or pass a Developer ID)
./scripts/sign.sh

# 4. package the DMG
./scripts/build-dmg.sh 0.1.0
```

Output lands in `dist/`.

## Repo layout

```
maut-vim/
├── nvim-config/                 the distribution (LazyVim + overrides)
│   ├── init.lua
│   ├── lua/config/              options, keymaps, lazy bootstrap
│   ├── lua/plugins/             colorscheme, yazi, which-key, dashboard, maut-sessions spec
│   └── maut-sessions/           the custom plugin (lua/maut-sessions/*)
├── app/
│   └── kitty.conf               bundled terminal config (tokyonight)
├── assets/
│   └── mautvim.icns             app icon
├── scripts/
│   ├── build-app.sh             assemble MautVim.app (bundles kitty + nvim + plugins)
│   ├── sign.sh                  codesign the app (incl. nested kitty) + dmg
│   └── build-dmg.sh             create the distributable DMG
└── dist/                        build output (gitignored)
```

## License

MIT — see [LICENSE](./LICENSE).
