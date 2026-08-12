#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

BIN_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/note"

# ---- OS check ─────────────────────────────────────────────────────-
OS="$(uname -s)"
if [ "$OS" = "Linux" ]; then
    echo "Warning: Linux support is experimental. Proceed with caution."
elif [ "$OS" != "Darwin" ]; then
    echo "Error: unsupported OS '$OS'. This installer supports macOS and Linux (experimental)."
    exit 1
fi

# ---- Check executable exists ───────────────────────────────────────
if [ ! -f "$ROOT_DIR/note" ]; then
    echo "Abort: 'note' executable not found in $ROOT_DIR."
    exit 1
fi

# ---- Check the executable was built for this OS ────────────────────
# Read the magic bytes rather than running the binary, so a mismatched
# build reports the reason instead of "Exec format error".
MAGIC="$(od -An -tx1 -N4 "$ROOT_DIR/note" 2>/dev/null | tr -d ' \n')"
case "$MAGIC" in
    7f454c46) BIN_OS="Linux" ;;                                       # ELF
    cffaedfe|cefaedfe|feedfacf|feedface|cafebabe|bebafeca) BIN_OS="Darwin" ;;  # Mach-O / universal
    *) BIN_OS="" ;;
esac

if [ -n "$BIN_OS" ] && [ "$BIN_OS" != "$OS" ]; then
    echo "Error: this package contains a $BIN_OS build of 'note', but this machine is $OS."
    echo "       Release archives are built on macOS and are not portable to Linux."
    echo "       On Linux, build from source instead:"
    echo "         ./setup.sh && ./build_py.sh   # or ./build_rs.sh for the Rust build"
    echo "         ./install.sh"
    exit 1
fi

# ---- Detect variant from executable ────────────────────────────────
# The python build is a PyInstaller onedir bundle, identified by its
# sibling _internal/ directory; only fall back to running the binary
# when that is absent (onefile python build, or rust).
if [ -d "$ROOT_DIR/_internal" ]; then
    VARIANT="python"
else
    VERSION_OUTPUT="$(cd "$ROOT_DIR" && ./note --version)"

    if echo "$VERSION_OUTPUT" | grep -q "(rust)"; then
        VARIANT="rust"
    elif echo "$VERSION_OUTPUT" | grep -q "(python)"; then
        VARIANT="python"
    else
        echo "Error: could not detect build type from 'note --version' output: '$VERSION_OUTPUT'"
        exit 1
    fi
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
elif [ "$OS" = "Linux" ]; then
    if command -v apt-get &>/dev/null; then
        echo "Installing fzf via apt …"
        sudo apt-get install -y fzf
    elif command -v dnf &>/dev/null; then
        echo "Installing fzf via dnf …"
        sudo dnf install -y fzf
    elif command -v pacman &>/dev/null; then
        echo "Installing fzf via pacman …"
        sudo pacman -S --noconfirm fzf
    else
        echo "Warning: fzf not found. Please install fzf manually (https://github.com/junegunn/fzf) to use \`note search\`."
    fi
else
    echo "Warning: fzf not found and no supported package manager is available."
    echo "Please install fzf manually (https://github.com/junegunn/fzf) to use \`note search\`."
fi

# ---- .noterc setup ─────────────────────────────────────────────────────
# $USER is not always exported (containers, cron, non-login shells), and
# `set -u` would abort here after the binary is already installed.
INSTALL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
USER_HOME="$(eval echo "~$INSTALL_USER")"
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
