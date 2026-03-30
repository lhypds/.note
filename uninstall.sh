#!/bin/bash

set -euo pipefail

BIN_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/note"

# ── OS check ─────────────────────────────────────────────────────────────────
OS="$(uname -s)"
if [ "$OS" != "Darwin" ]; then
    echo "Error: this uninstaller currently supports macOS only."
    exit 1
fi

REMOVED=0

# Remove binary / symlink from BIN_DIR
if [ -e "$BIN_DIR/note" ] || [ -L "$BIN_DIR/note" ]; then
    sudo rm -f "$BIN_DIR/note"
    echo "Removed: $BIN_DIR/note"
    REMOVED=1
fi

# Remove Python bundle directory (only present for python installs)
if [ -d "$LIB_DIR" ]; then
    sudo rm -rf "$LIB_DIR"
    echo "Removed: $LIB_DIR"
    REMOVED=1
fi

if [ "$REMOVED" -eq 0 ]; then
    echo "Nothing to uninstall — note does not appear to be installed."
else
    echo ""
    echo "\`note\` executable has been uninstalled from:"
    if [ -e "$BIN_DIR/note" ] || [ -L "$BIN_DIR/note" ]; then
        echo "  - $BIN_DIR/note"
    fi
    if [ -d "$LIB_DIR" ]; then
        echo "  - $LIB_DIR"
    fi
fi
