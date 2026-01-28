# lspmux-rust-analyzer

WARNING: This is mostly vibe coded and works for me (Rain) personally. This may
or may not work for you.

Uses [lspmux](https://codeberg.org/p2502/lspmux), a Language Server Protocol multiplexer, to share
a single rust-analyzer instance across multiple LSP clients. This reduces memory and CPU usage when
running multiple editors or Claude Code sessions on the same workspace.

## Problem

Each LSP client (editor, Claude Code session, etc.) spawns its own rust-analyzer
process. On systems running multiple editors, this causes significant memory
pressure since rust-analyzer is memory-intensive.

## Solution

lspmux acts as an intermediary between LSP clients and language servers:

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Claude Code │  │     Zed      │  │    Neovim    │
│ (LSP client) │  │ (LSP client) │  │ (LSP client) │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       │ stdio           │ stdio           │ stdio
       ▼                 ▼                 ▼
┌────────────────────────────────────────────────────┐
│              lspmux client shim                    │
│        (invoked as "rust-analyzer")                │
└────────────────────────┬───────────────────────────┘
                         │ socket (localhost:27631)
                         ▼
┌────────────────────────────────────────────────────┐
│              lspmux server                         │
│        (systemd user service)                      │
└────────────────────────┬───────────────────────────┘
                         │ manages
                         ▼
┌────────────────────────────────────────────────────┐
│       rust-analyzer (one per workspace)            │
└────────────────────────────────────────────────────┘
```

## Quick start

```bash
./setup
```

The setup script:
1. Downloads rust-analyzer from GitHub releases (with SHA256 verification)
2. Installs lspmux via `cargo install --locked` if not found
3. Installs systemd services (Linux) or launchd agents (macOS)

After setup completes, configure your editor (see below).

## Editor configuration

### Claude Code

```bash
claude plugin marketplace add /path/to/lspmux-rust-analyzer
claude plugin disable rust-analyzer-lsp@claude-plugins-official --scope user
claude plugin install lspmux-rust@lspmux-plugins --scope user
```

### Zed

In `~/.config/zed/settings.json`:

```json
{
  "lsp": {
    "rust-analyzer": {
      "binary": {
        "path": "lspmux",
        "arguments": ["client", "--server-path", "/path/to/.local/share/lspmux-rust-analyzer/current/rust-analyzer"]
      }
    }
  }
}
```

Replace `/path/to` with the actual path (e.g., `/home/username` or the value of `$HOME`).

### Neovim (untested)

With [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig):

```lua
require('lspconfig').rust_analyzer.setup {
  cmd = {
    "lspmux", "client", "--server-path",
    vim.fn.expand("$HOME/.local/share/lspmux-rust-analyzer/current/rust-analyzer")
  },
}
```

Or if using [rustaceanvim](https://github.com/mrcjkb/rustaceanvim):

```lua
vim.g.rustaceanvim = {
  server = {
    cmd = function()
      return {
        "lspmux", "client", "--server-path",
        vim.fn.expand("$HOME/.local/share/lspmux-rust-analyzer/current/rust-analyzer")
      }
    end,
  },
}
```

### Vim (untested)

With [vim-lsp](https://github.com/prabirshrestha/vim-lsp):

```vim
if executable('lspmux')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'rust-analyzer',
    \ 'cmd': ['lspmux', 'client', '--server-path', expand('$HOME/.local/share/lspmux-rust-analyzer/current/rust-analyzer')],
    \ 'allowlist': ['rust'],
    \ })
endif
```

With [coc.nvim](https://github.com/neoclide/coc.nvim), in `coc-settings.json`:

```json
{
  "languageserver": {
    "rust-analyzer": {
      "command": "lspmux",
      "args": ["client", "--server-path", "/path/to/.local/share/lspmux-rust-analyzer/current/rust-analyzer"],
      "filetypes": ["rust"]
    }
  }
}
```

## Requirements

- Linux (systemd) or macOS (launchd)
- Rust toolchain (for `cargo install`)
- curl, jq

## Directory structure

All paths respect the XDG base directory specification:

### rust-analyzer

| Purpose | Default path |
|---------|--------------|
| Binary versions | `$XDG_DATA_HOME/lspmux-rust-analyzer/versions/` or `~/.local/share/lspmux-rust-analyzer/versions/` |
| Active version | `$XDG_DATA_HOME/lspmux-rust-analyzer/current` or `~/.local/share/lspmux-rust-analyzer/current` (symlink) |
| Update script | `$XDG_DATA_HOME/lspmux-rust-analyzer/bin/update-rust-analyzer` or `~/.local/share/lspmux-rust-analyzer/bin/update-rust-analyzer` |
| Update log | `$XDG_STATE_HOME/lspmux-rust-analyzer/update.log` or `~/.local/state/lspmux-rust-analyzer/update.log` |

### lspmux

| Purpose | Default path |
|---------|--------------|
| Binary | `$CARGO_HOME/bin/lspmux` or `~/.cargo/bin/lspmux` |
| Config | `$XDG_CONFIG_HOME/lspmux/config.toml` or `~/.config/lspmux/config.toml` |
| Log (macOS) | `$XDG_STATE_HOME/lspmux/server.log` or `~/.local/state/lspmux/server.log` |

### Services

| Platform | Path |
|----------|------|
| Linux | `$XDG_CONFIG_HOME/systemd/user/` or `~/.config/systemd/user/` |
| macOS | `~/Library/LaunchAgents/` |

## Managing services

### lspmux server

**Linux (systemd):**
```bash
systemctl --user status lspmux
systemctl --user restart lspmux
journalctl --user -u lspmux -f
```

**macOS (launchd):**
```bash
launchctl list | grep lspmux
launchctl stop com.lspmux.server
launchctl start com.lspmux.server
tail -f "${XDG_STATE_HOME:-$HOME/.local/state}/lspmux/server.log"
```

### Automatic updates

A daily timer/agent updates rust-analyzer to the latest release.

**Linux:**
```bash
systemctl --user status rust-analyzer-update.timer
systemctl --user start rust-analyzer-update.service  # manual update
```

**macOS:**
```bash
# Manual update
"${XDG_DATA_HOME:-$HOME/.local/share}/lspmux-rust-analyzer/bin/update-rust-analyzer"
```

## Configuration

### lspmux config

`${XDG_CONFIG_HOME:-$HOME/.config}/lspmux/config.toml`:
```toml
instance_timeout = 300       # Keep server for 5 min after last client
gc_interval = 10             # Check for idle servers every 10 sec
listen = ["127.0.0.1", 27631]
connect = ["127.0.0.1", 27631]
pass_environment = ["CARGO_HOME", "RUSTUP_HOME", "PATH", "HOME", "USER"]
```

## Troubleshooting

### LSP not working

1. Check lspmux server is running:
   ```bash
   systemctl --user status lspmux  # Linux
   launchctl list | grep lspmux    # macOS
   ```

2. Check rust-analyzer works:
   ```bash
   "${XDG_DATA_HOME:-$HOME/.local/share}/lspmux-rust-analyzer/current/rust-analyzer" --version
   ```

3. Check lspmux can connect:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | \
     lspmux client --server-path "${XDG_DATA_HOME:-$HOME/.local/share}/lspmux-rust-analyzer/current/rust-analyzer"
   ```
   You should see JSON output. Press Ctrl+C to exit.

4. For Claude Code, check the plugin is installed:
   ```bash
   claude plugin list
   ```

### Multiple rust-analyzer processes

Verify only one rust-analyzer is running per workspace:
```bash
pgrep -a rust-analyzer
```

If multiple processes exist, lspmux may not be configured correctly in your editor.

## Uninstall

```bash
# Uninstall Claude Code plugin and marketplace
claude plugin uninstall lspmux-rust@lspmux-plugins --scope user
claude plugin marketplace remove lspmux-plugins
claude plugin enable rust-analyzer-lsp@claude-plugins-official --scope user

# Stop services (Linux)
systemctl --user disable --now lspmux.service rust-analyzer-update.timer

# Stop services (macOS)
launchctl unload ~/Library/LaunchAgents/com.lspmux.server.plist
launchctl unload ~/Library/LaunchAgents/com.rust-analyzer.update.plist

# Remove files
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/lspmux-rust-analyzer"
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/lspmux-rust-analyzer"
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/lspmux"
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/lspmux"
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/lspmux.service"
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/rust-analyzer-update."*
rm -rf ~/Library/LaunchAgents/com.lspmux.server.plist
rm -rf ~/Library/LaunchAgents/com.rust-analyzer.update.plist
```

## License

MIT
