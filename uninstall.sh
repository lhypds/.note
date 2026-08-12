#!/bin/sh
#
# Remove `note` from /usr/local, on macOS or Linux.
#
# POSIX sh on purpose, to match install.sh: the musl build runs on
# distributions that ship no bash at all.

set -eu

BIN_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/note"

# ── OS check ─────────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
    Darwin|Linux) ;;
    *)
        echo "Error: this uninstaller supports macOS and Linux only."
        exit 1
        ;;
esac

# ── Privilege escalation ─────────────────────────────────────────────────────
# Root shells on Linux often have no sudo installed at all. SUDO is
# deliberately unquoted where it is used.
if [ "$(id -u)" -eq 0 ] || ! command -v sudo >/dev/null 2>&1; then
    SUDO=""
else
    SUDO="sudo"
fi

REMOVED=0
REMOVED_BIN=0
REMOVED_LIB=0
REMOVED_DATA=0

# Remove binary / symlink from BIN_DIR
if [ -e "$BIN_DIR/note" ] || [ -L "$BIN_DIR/note" ]; then
    $SUDO rm -f "$BIN_DIR/note"
    echo "Removed: $BIN_DIR/note"
    REMOVED=1
    REMOVED_BIN=1
fi

# Remove Python bundle directory (only present for python installs)
if [ -d "$LIB_DIR" ]; then
    $SUDO rm -rf "$LIB_DIR"
    echo "Removed: $LIB_DIR"
    REMOVED=1
    REMOVED_LIB=1
fi

# Remove user data directory
NOTE_DATA_DIR="$HOME/.note"
if [ -d "$NOTE_DATA_DIR" ]; then
    rm -rf "$NOTE_DATA_DIR"
    echo "Removed: $NOTE_DATA_DIR"
    REMOVED=1
    REMOVED_DATA=1
fi

if [ "$REMOVED" -eq 0 ]; then
    echo "Nothing to uninstall — note does not appear to be installed."
else
    echo ""
    echo "\`note\` executable has been uninstalled from:"
    if [ "$REMOVED_BIN" -eq 1 ]; then
        echo "  - $BIN_DIR/note"
    fi
    if [ "$REMOVED_LIB" -eq 1 ]; then
        echo "  - $LIB_DIR"
    fi
    if [ "$REMOVED_DATA" -eq 1 ]; then
        echo "  - $NOTE_DATA_DIR"
    fi
fi
