# Justfile for lspmux-rust-analyzer

# List available recipes
default:
    @just --list

# Run shellcheck on all shell scripts
lint:
    shellcheck setup bin/update-rust-analyzer plugins/lspmux-rust/bin/*
