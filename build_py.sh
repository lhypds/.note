#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
# PYTHON_BIN can be overridden to build outside the repo's virtualenv — the
# Linux cross-build does that, pointing at an interpreter inside its container.
PYTHON_BIN="${PYTHON_BIN:-$ROOT_DIR/.venv/bin/python}"
NOTE_ENTRY_FILE="$ROOT_DIR/note.py"
BUILD_MODE="onedir"

if [ "${1:-}" = "--onefile" ]; then
	BUILD_MODE="onefile"
elif [ -n "${1:-}" ]; then
	echo "Usage: ./build_py.sh [--onefile]"
	echo "Default build mode is onedir for faster run speed."
	exit 1
fi

if [ ! -x "$PYTHON_BIN" ]; then
	echo "Error: Python virtual environment not found at $PYTHON_BIN"
	echo "Run ./setup.sh first."
	exit 1
fi

if [ ! -f "$NOTE_ENTRY_FILE" ]; then
	echo "Error: Entry file not found: $NOTE_ENTRY_FILE"
	exit 1
fi

echo "Building note.py with PyInstaller ($BUILD_MODE)..."
cd "$ROOT_DIR"

rm -rf build dist note.spec

build_target() {
	local name="$1"
	local entry_file="$2"
	local contents_dir="$3"

	local pyinstaller_args=(
		--clean
		--noconfirm
		--add-data "VERSION:."
		--hidden-import commands.format
		--hidden-import commands.markdown
		--hidden-import commands.create
		--name "$name"
		"$entry_file"
	)

	if [ "$BUILD_MODE" = "onefile" ]; then
		pyinstaller_args=(--onefile "${pyinstaller_args[@]}")
	else
		pyinstaller_args=(--onedir --contents-directory "$contents_dir" "${pyinstaller_args[@]}")
	fi

	"$PYTHON_BIN" -m PyInstaller "${pyinstaller_args[@]}"
}

build_target "note" "$NOTE_ENTRY_FILE" "_internal"

if [ "$BUILD_MODE" = "onefile" ]; then
	cp "$ROOT_DIR/dist/note" "$ROOT_DIR/note"
	chmod +x "$ROOT_DIR/note"

	rm -rf "$ROOT_DIR/_internal"
	echo "Build complete: $ROOT_DIR/note"
else
	cp "$ROOT_DIR/dist/note/note" "$ROOT_DIR/note"
	chmod +x "$ROOT_DIR/note"

	rm -rf "$ROOT_DIR/_internal"
	cp -R "$ROOT_DIR/dist/note/_internal" "$ROOT_DIR/_internal"
	echo "Build complete: $ROOT_DIR/note"
fi

echo "Copied executable to: $ROOT_DIR/note"

echo "Warming up executable..."
"$ROOT_DIR/note" --help >/dev/null 2>&1 || true
