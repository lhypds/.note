#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$ROOT_DIR/release"

# Accept VERSION, one or more ZIP paths, and any further assets (SHA256SUMS)
# as arguments, or derive them
EXTRA_ASSETS=()
if [ $# -ge 3 ]; then
	VERSION="$1"
	PYTHON_ZIP_PATH="$2"
	RUST_ZIP_PATH="$3"
	if [ $# -ge 4 ]; then
		EXTRA_ASSETS=("${@:4}")
	fi
elif [ $# -ge 2 ]; then
	VERSION="$1"
	PYTHON_ZIP_PATH="$2"
	RUST_ZIP_PATH=""
else
	VERSION_FILE="$ROOT_DIR/VERSION"
	if [ ! -f "$VERSION_FILE" ]; then
		echo "Error: VERSION file not found."
		exit 1
	fi
	VERSION="v$(cat "$VERSION_FILE" | tr -d '[:space:]')"
	PYTHON_ZIP_PATH="$RELEASE_DIR/dot_note_python_${VERSION}.zip"
	RUST_ZIP_PATH="$RELEASE_DIR/dot_note_rust_${VERSION}.zip"
	if [ -f "$RELEASE_DIR/SHA256SUMS" ]; then
		EXTRA_ASSETS=("$RELEASE_DIR/SHA256SUMS")
	fi
fi

# Check zips exist
if [ ! -f "$PYTHON_ZIP_PATH" ]; then
	echo "Error: $PYTHON_ZIP_PATH not found. Run release.sh first."
	exit 1
fi
if [ -n "$RUST_ZIP_PATH" ] && [ ! -f "$RUST_ZIP_PATH" ]; then
	echo "Error: $RUST_ZIP_PATH not found. Run release.sh first."
	exit 1
fi
for A in ${EXTRA_ASSETS[@]+"${EXTRA_ASSETS[@]}"}; do
	if [ ! -f "$A" ]; then
		echo "Error: $A not found. Run release.sh first."
		exit 1
	fi
done

# Check gh is available
if ! command -v gh &>/dev/null; then
	echo "Error: GitHub CLI (gh) is not installed. Install it from https://cli.github.com"
	exit 1
fi

echo "Ready to publish release:"
echo "  Tag:    $VERSION"
echo "  Asset:  $PYTHON_ZIP_PATH"
[ -n "$RUST_ZIP_PATH" ] && echo "  Asset:  $RUST_ZIP_PATH"
for A in ${EXTRA_ASSETS[@]+"${EXTRA_ASSETS[@]}"}; do
	echo "  Asset:  $A"
done
echo ""
read -r -p "Release notes (leave blank for default): " RELEASE_NOTES
if [ -z "$RELEASE_NOTES" ]; then
	RELEASE_NOTES="Release $VERSION"
fi
echo ""
read -r -p "Publish to GitHub? [Y/n]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
	echo "Aborted."
	exit 0
fi

# Collect assets
ZIP_ASSETS=("$PYTHON_ZIP_PATH")
[ -n "$RUST_ZIP_PATH" ] && ZIP_ASSETS+=("$RUST_ZIP_PATH")
if [ ${#EXTRA_ASSETS[@]} -gt 0 ]; then
	ZIP_ASSETS+=("${EXTRA_ASSETS[@]}")
fi

# Create tag and GitHub release, upload zips
gh release create "$VERSION" "${ZIP_ASSETS[@]}" \
	--title "$VERSION" \
	--notes "$RELEASE_NOTES"

echo "Published release $VERSION with ${ZIP_ASSETS[*]}"
