#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

BIN_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/note"

# ---- OS check ─────────────────────────────────────────────────────-
OS="$(uname -s)"
if [ "$OS" != "Darwin" ]; then
    echo "Error: this installer currently supports macOS only."
    exit 1
fi

# ---- Check executable exists ───────────────────────────────────────
if [ ! -f "$ROOT_DIR/note" ]; then
    echo "Abort: 'note' executable not found in $ROOT_DIR."
    exit 1
fi

# ---- Detect variant from executable ────────────────────────────────
VERSION_OUTPUT="$(cd "$ROOT_DIR" && ./note --version)"

if echo "$VERSION_OUTPUT" | grep -q "(rust)"; then
    VARIANT="rust"
elif echo "$VERSION_OUTPUT" | grep -q "(python)"; then
    VARIANT="python"
else
    echo "Error: could not detect build type from 'note --version' output: '$VERSION_OUTPUT'"
    exit 1
fi

echo "Detected build type: $VARIANT"

# ---- Install ───────────────────────────────────────────────────────
echo "Installing \`note\` ($VARIANT) …"

if [ "$VARIANT" = "rust" ]; then
    # Single self-contained binary — copy directly into BIN_DIR
    sudo install -m 755 "$ROOT_DIR/note" "$BIN_DIR/note"
    echo "Installed to \`$BIN_DIR/note\`"

elif [ "$VARIANT" = "python" ]; then
    # PyInstaller onedir bundle — install bundle then symlink
    sudo rm -rf "$LIB_DIR"
    sudo mkdir -p "$LIB_DIR"
    sudo cp -R "$ROOT_DIR/." "$LIB_DIR/"
    sudo chmod 755 "$LIB_DIR/note"

    # Remove any previous binary/symlink
    sudo rm -f "$BIN_DIR/note"
    sudo ln -s "$LIB_DIR/note" "$BIN_DIR/note"

    echo "Installed bundle: $LIB_DIR"
    echo "Symlinked:        $BIN_DIR/note -> $LIB_DIR/note"
fi

# ---- fzf ───────────────────────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
    echo "fzf already installed."
elif command -v brew &>/dev/null; then
    echo "Installing fzf via Homebrew …"
    brew install fzf
else
    echo "Warning: fzf not found and Homebrew is not available."
    echo "Please install fzf manually (https://github.com/junegunn/fzf) to use \`note search\`."
fi

# ---- .noterc setup ─────────────────────────────────────────────────────
USER_HOME="$(eval echo ~${SUDO_USER:-$USER})"
NOTERC_PATH="$USER_HOME/.noterc"
if [ ! -f "$NOTERC_PATH" ]; then
    echo "Creating .noterc file at $NOTERC_PATH …"
    echo "notePath=" > "$NOTERC_PATH"
    echo ".noterc file created. Please update it with your configuration if needed."
else
    echo ".noterc file already exists at $NOTERC_PATH."
fi

echo ""
echo "\`note\` executable has been installed to \`$BIN_DIR/note\`."
echo ".noterc file is located at \`$NOTERC_PATH\`."
