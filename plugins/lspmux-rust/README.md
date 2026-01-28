# lspmux-rust Claude plugin

This plugin configures Claude Code to use rust-analyzer through lspmux, enabling
multiple Claude sessions to share a single rust-analyzer instance per workspace.

## Requirements

- lspmux server must be running (`systemctl --user status lspmux` on Linux)
- rust-analyzer must be in PATH (installed via the setup script)

## Installation

Install via the lspmux-plugins marketplace:

```bash
# Add the marketplace
claude plugin marketplace add /path/to/lspmux-rust-analyzer

# Disable the official rust-analyzer plugin
claude plugin disable rust-analyzer-lsp@claude-plugins-official --scope user

# Install this plugin
claude plugin install lspmux-rust@lspmux-plugins --scope user
```

## How it works

Instead of spawning rust-analyzer directly, this plugin invokes `lspmux client`,
which connects to the lspmux server over a local socket. The server manages
rust-analyzer instances, creating one per workspace and sharing it across all
connected clients.
