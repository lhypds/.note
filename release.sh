#!/bin/bash

set -euo pipefail

# Clear previous release artifacts
rm -rf release/
echo "Cleared previous release artifacts."

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$ROOT_DIR/release"

# Create release folders
mkdir -p "$RELEASE_DIR/python"
mkdir -p "$RELEASE_DIR/rust"

# Build Python binaries and move to release/python
echo "Building Python..."
"$ROOT_DIR/build_py.sh"
mv "$ROOT_DIR/note" "$RELEASE_DIR/python/note"
if [ -d "$ROOT_DIR/_internal" ]; then
	mv "$ROOT_DIR/_internal" "$RELEASE_DIR/python/_internal"
fi
echo "Python binaries moved to $RELEASE_DIR/python"

# Build Rust binaries and move to release/rust
echo "Building Rust..."
"$ROOT_DIR/build_rs.sh"
mv "$ROOT_DIR/note" "$RELEASE_DIR/rust/note"
echo "Rust binaries moved to $RELEASE_DIR/rust"

echo "Release complete: $RELEASE_DIR"

VERSION="$(cat "$ROOT_DIR/VERSION" | tr -d '[:space:]')"
ZIP_NAME="dot_note_v${VERSION}.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
TMP_ZIP_PATH="$ROOT_DIR/$ZIP_NAME"

if [ -f "$ZIP_PATH" ]; then
	rm -f "$ZIP_PATH"
fi
if [ -f "$TMP_ZIP_PATH" ]; then
	rm -f "$TMP_ZIP_PATH"
fi

# Copy install/uninstall scripts to python and rust folders
cp "$ROOT_DIR/install.sh" "$RELEASE_DIR/python/install.sh"
cp "$ROOT_DIR/uninstall.sh" "$RELEASE_DIR/python/uninstall.sh"
chmod +x "$RELEASE_DIR/python/install.sh" "$RELEASE_DIR/python/uninstall.sh"
echo "Copied install.sh and uninstall.sh to $RELEASE_DIR/python"

cp "$ROOT_DIR/install.sh" "$RELEASE_DIR/rust/install.sh"
cp "$ROOT_DIR/uninstall.sh" "$RELEASE_DIR/rust/uninstall.sh"
chmod +x "$RELEASE_DIR/rust/install.sh" "$RELEASE_DIR/rust/uninstall.sh"
echo "Copied install.sh and uninstall.sh to $RELEASE_DIR/rust"

# Copy documentation and license files
cp "$ROOT_DIR/doc/installation/README.txt" "$RELEASE_DIR/README.txt"
cp "$ROOT_DIR/LICENSE" "$RELEASE_DIR/LICENSE"
echo "Copied README.txt and LICENSE to $RELEASE_DIR"

cd "$RELEASE_DIR"
zip -r -9 "$TMP_ZIP_PATH" "python" "rust" "README.txt" "LICENSE"
mv "$TMP_ZIP_PATH" "$ZIP_PATH"
echo "Created archive: $ZIP_PATH"

"$ROOT_DIR/release_gh.sh"
