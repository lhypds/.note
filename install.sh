#!/bin/sh
#
# Install the `note` in this directory to /usr/local, on macOS or Linux.
#
# POSIX sh on purpose: the musl build runs on distributions that ship no bash
# at all, and `note update` re-runs this script after downloading a release.

set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

BIN_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/note"

# ---- OS ────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
    Darwin|Linux) ;;
    *)
        echo "Error: unsupported OS '$OS'. This installer supports macOS and Linux."
        exit 1
        ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
    amd64) ARCH="x86_64" ;;
    aarch64) ARCH="arm64" ;;
esac

# ---- Privilege escalation ──────────────────────────────────────────
# /usr/local needs root on most systems, but plenty of Linux boxes run as root
# with no sudo installed at all, so only reach for sudo when it is both needed
# and present. SUDO is deliberately unquoted where it is used.
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
elif [ -w "$BIN_DIR" ]; then
    SUDO=""
else
    echo "Error: $BIN_DIR needs root to write to, and sudo is not installed."
    echo "       Re-run this as root, or install into a directory you own:"
    echo "         curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh | sh -s -- --prefix \"\$HOME/.local\""
    exit 1
fi

# ---- Check executable exists ───────────────────────────────────────
if [ ! -f "$ROOT_DIR/note" ]; then
    echo "Abort: 'note' executable not found in $ROOT_DIR."
    exit 1
fi

# ---- Check the executable was built for this machine ───────────────
# Read the header bytes rather than running the binary, so a mismatched build
# reports the reason instead of "Exec format error" or "Bad CPU type". ELF puts
# e_machine in a little-endian half at offset 18; Mach-O puts cputype at
# offset 4.
HEADER="$(od -An -tx1 -N20 "$ROOT_DIR/note" 2>/dev/null | tr -d ' \n')"
BIN_OS=""
BIN_ARCH=""
case "$HEADER" in
    7f454c46*)                                              # ELF
        BIN_OS="Linux"
        case "$(echo "$HEADER" | cut -c37-40)" in
            3e00) BIN_ARCH="x86_64" ;;
            b700) BIN_ARCH="arm64" ;;
        esac
        ;;
    cafebabe*|bebafeca*|cafebabf*)                          # universal (fat)
        BIN_OS="Darwin"
        BIN_ARCH="$ARCH"                                    # holds several
        ;;
    cffaedfe*|cefaedfe*|feedfacf*|feedface*)                # Mach-O
        BIN_OS="Darwin"
        case "$(echo "$HEADER" | cut -c9-16)" in
            07000001) BIN_ARCH="x86_64" ;;
            0c000001) BIN_ARCH="arm64" ;;
        esac
        ;;
esac

mismatch() {
    echo "Error: this package is built for $1, but this machine is $2."
    echo "       Download the archive for ${OS}/${ARCH} instead:"
    echo "         https://github.com/lhypds/.note/releases/latest"
    echo "       or build from source:"
    echo "         ./build_rs.sh   # or ./setup.sh && ./build_py.sh for the python build"
    echo "         ./install.sh"
    exit 1
}

if [ -n "$BIN_OS" ] && [ "$BIN_OS" != "$OS" ]; then
    mismatch "$BIN_OS" "$OS"
fi
if [ -n "$BIN_ARCH" ] && [ "$BIN_ARCH" != "$ARCH" ]; then
    mismatch "$BIN_ARCH" "$ARCH"
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
echo "Installing \`note\` ($VARIANT) for ${OS}/${ARCH} …"

$SUDO mkdir -p "$BIN_DIR"

if [ "$VARIANT" = "rust" ]; then
    # Single self-contained binary — copy directly into BIN_DIR
    $SUDO install -m 755 "$ROOT_DIR/note" "$BIN_DIR/note"
    echo "Installed to \`$BIN_DIR/note\`"

elif [ "$VARIANT" = "python" ]; then
    # PyInstaller onedir bundle — install bundle then symlink
    $SUDO rm -rf "$LIB_DIR"
    $SUDO mkdir -p "$LIB_DIR"
    $SUDO cp -R "$ROOT_DIR/." "$LIB_DIR/"
    $SUDO chmod 755 "$LIB_DIR/note"

    # Remove any previous binary/symlink
    $SUDO rm -f "$BIN_DIR/note"
    $SUDO ln -s "$LIB_DIR/note" "$BIN_DIR/note"

    echo "Installed bundle: $LIB_DIR"
    echo "Symlinked:        $BIN_DIR/note -> $LIB_DIR/note"
fi

# ---- fzf ───────────────────────────────────────────────────────────────────
if command -v fzf >/dev/null 2>&1; then
    echo "fzf already installed."
elif command -v brew >/dev/null 2>&1; then
    echo "Installing fzf via Homebrew …"
    brew install fzf
elif [ "$OS" = "Linux" ]; then
    if command -v apt-get >/dev/null 2>&1; then
        echo "Installing fzf via apt …"
        $SUDO apt-get install -y fzf || echo "Warning: could not install fzf via apt."
    elif command -v dnf >/dev/null 2>&1; then
        echo "Installing fzf via dnf …"
        $SUDO dnf install -y fzf || echo "Warning: could not install fzf via dnf."
    elif command -v pacman >/dev/null 2>&1; then
        echo "Installing fzf via pacman …"
        $SUDO pacman -S --noconfirm fzf || echo "Warning: could not install fzf via pacman."
    elif command -v zypper >/dev/null 2>&1; then
        echo "Installing fzf via zypper …"
        $SUDO zypper install -y fzf || echo "Warning: could not install fzf via zypper."
    elif command -v apk >/dev/null 2>&1; then
        echo "Installing fzf via apk …"
        $SUDO apk add fzf || echo "Warning: could not install fzf via apk."
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
    if [ -n "${SUDO_USER:-}" ]; then
        chown "$SUDO_USER" "$NOTERC_PATH" 2>/dev/null || true
    fi
    echo ".noterc file created. Please update it with your configuration if needed."
else
    echo ".noterc file already exists at $NOTERC_PATH."
fi

echo ""
echo "\`note\` executable has been installed to \`$BIN_DIR/note\`."
echo ".noterc file is located at \`$NOTERC_PATH\`."

case ":${PATH:-}:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo ""
        echo "warning: $BIN_DIR is not on your PATH; add it with"
        echo "  export PATH=\"$BIN_DIR:\$PATH\""
        ;;
esac
