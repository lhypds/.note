#!/bin/bash
#
# Publish a GitHub release and upload its archives.
#
#   ./release_gh.sh                          # v<VERSION> with everything in release/
#   ./release_gh.sh v0.0.23 a.zip b.zip ...  # an explicit tag and asset list

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$ROOT_DIR/release"

ASSETS=()
if [ $# -ge 1 ]; then
	VERSION="$1"
	shift
	ASSETS=("$@")
else
	VERSION_FILE="$ROOT_DIR/VERSION"
	if [ ! -f "$VERSION_FILE" ]; then
		echo "Error: VERSION file not found."
		exit 1
	fi
	VERSION="v$(tr -d '[:space:]' <"$VERSION_FILE")"
fi

# With no explicit assets, take whatever release.sh left behind.
if [ ${#ASSETS[@]} -eq 0 ]; then
	shopt -s nullglob
	ASSETS=("$RELEASE_DIR"/*.zip)
	shopt -u nullglob
	[ -f "$RELEASE_DIR/SHA256SUMS" ] && ASSETS+=("$RELEASE_DIR/SHA256SUMS")
fi

if [ ${#ASSETS[@]} -eq 0 ]; then
	echo "Error: no release assets found in $RELEASE_DIR. Run release.sh first."
	exit 1
fi

for A in "${ASSETS[@]}"; do
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
for A in "${ASSETS[@]}"; do
	echo "  Asset:  $(basename "$A")"
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

# Create tag and GitHub release, upload assets
gh release create "$VERSION" "${ASSETS[@]}" \
	--title "$VERSION" \
	--notes "$RELEASE_NOTES"

echo "Published release $VERSION with ${#ASSETS[@]} assets."
