#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
NOTE_ENTRY_FILE="$ROOT_DIR/note.py"
NOTEMD_ENTRY_FILE="$ROOT_DIR/note_markdown.py"
BUILD_MODE="onedir"

if [ "${1:-}" = "--onefile" ]; then
	BUILD_MODE="onefile"
elif [ -n "${1:-}" ]; then
	echo "Usage: ./build.sh [--onefile]"
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

if [ ! -f "$NOTEMD_ENTRY_FILE" ]; then
	echo "Error: Entry file not found: $NOTEMD_ENTRY_FILE"
	exit 1
fi

echo "Building note.py and note_markdown.py with PyInstaller ($BUILD_MODE)..."
cd "$ROOT_DIR"

rm -rf build dist note.spec notemd.spec

build_target() {
	local name="$1"
	local entry_file="$2"
	local contents_dir="$3"

	local pyinstaller_args=(
		--clean
		--noconfirm
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

build_target "note" "$NOTE_ENTRY_FILE" "_internal_note"
build_target "notemd" "$NOTEMD_ENTRY_FILE" "_internal_notemd"

if [ "$BUILD_MODE" = "onefile" ]; then
	cp "$ROOT_DIR/dist/note" "$ROOT_DIR/note"
	cp "$ROOT_DIR/dist/notemd" "$ROOT_DIR/notemd"
	chmod +x "$ROOT_DIR/note" "$ROOT_DIR/notemd"

	rm -rf "$ROOT_DIR/_internal_note" "$ROOT_DIR/_internal_notemd"
	echo "Build complete: $ROOT_DIR/note and $ROOT_DIR/notemd"
else
 	cp "$ROOT_DIR/dist/note/note" "$ROOT_DIR/note"
	cp "$ROOT_DIR/dist/notemd/notemd" "$ROOT_DIR/notemd"
	chmod +x "$ROOT_DIR/note" "$ROOT_DIR/notemd"

	rm -rf "$ROOT_DIR/_internal_note" "$ROOT_DIR/_internal_notemd"
	cp -R "$ROOT_DIR/dist/note/_internal_note" "$ROOT_DIR/_internal_note"
	cp -R "$ROOT_DIR/dist/notemd/_internal_notemd" "$ROOT_DIR/_internal_notemd"
	echo "Build complete: $ROOT_DIR/note and $ROOT_DIR/notemd"
fi

echo "Copied executables to: $ROOT_DIR/note, $ROOT_DIR/notemd"

echo "Warming up executables..."
"$ROOT_DIR/note" --help >/dev/null 2>&1 || true
"$ROOT_DIR/notemd" --help >/dev/null 2>&1 || true
