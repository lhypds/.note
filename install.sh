#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

BIN_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/note"

# ── OS check ────────────────────────────────────────────────────────────────
OS="$(uname -s)"
if [ "$OS" != "Darwin" ]; then
    echo "Error: this installer currently supports macOS only."
    exit 1
fi

# ── Choose variant ───────────────────────────────────────────────────────────
VARIANT="${1:-}"

if [ -z "$VARIANT" ]; then
    echo "Choose which build to install:"
    echo "1) rust   (recommended – single binary, no dependencies)"
    echo "2) python (PyInstaller bundle)"
    read -r -p "Enter choice [1-2, default 1]: " CHOICE
    CHOICE="${CHOICE:-1}"

    case "$CHOICE" in
        1|rust)   VARIANT="rust"   ;;
        2|python) VARIANT="python" ;;
        *)
            echo "Error: invalid choice."
            exit 1
            ;;
    esac
fi

case "$VARIANT" in
    rust|python) ;;
    *)
        echo "Error: unknown variant '$VARIANT'. Use 'rust' or 'python'."
        exit 1
        ;;
esac

# ── Locate release binary ─────────────────────────────────────────────────
RELEASE_DIR="$ROOT_DIR/release/$VARIANT"

if [ ! -f "$RELEASE_DIR/note" ]; then
    echo "Error: binary not found at $RELEASE_DIR/note"
    echo "Run './build.sh $VARIANT' first."
    exit 1
fi

# ── Install ───────────────────────────────────────────────────────────────
echo "Installing note ($VARIANT) …"

if [ "$VARIANT" = "rust" ]; then
    # Single self-contained binary — copy directly into BIN_DIR
    sudo install -m 755 "$RELEASE_DIR/note" "$BIN_DIR/note"
    echo "Installed: $BIN_DIR/note"

elif [ "$VARIANT" = "python" ]; then
    # PyInstaller onedir bundle — install bundle then symlink
    sudo rm -rf "$LIB_DIR"
    sudo mkdir -p "$LIB_DIR"
    sudo cp -R "$RELEASE_DIR/." "$LIB_DIR/"
    sudo chmod 755 "$LIB_DIR/note"

    # Remove any previous binary/symlink
    sudo rm -f "$BIN_DIR/note"
    sudo ln -s "$LIB_DIR/note" "$BIN_DIR/note"

    echo "Installed bundle: $LIB_DIR"
    echo "Symlinked:        $BIN_DIR/note -> $LIB_DIR/note"
fi

echo ""
echo "\`note\` executable has been installed to \`$BIN_DIR/note\`. You can now run:"
echo "note create ..."
