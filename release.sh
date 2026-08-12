#!/bin/bash
#
# Build and package `note` for every platform this machine can produce, then
# hand the archives to release_gh.sh.
#
#   ./release.sh                # host platform + linux (if docker is running)
#   ./release.sh --no-linux     # host platform only
#   ./release.sh --no-publish   # build and zip, but do not touch GitHub
#
# Archives are named dot_note_<variant>_v<version>_<os>_<arch>.zip, which is
# what get.sh, get.ps1 and `note update` look for.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"

with_linux=auto
publish=yes
linux_arches=(x86_64)

while [ $# -gt 0 ]; do
	case "$1" in
	--linux) with_linux=yes ;;
	--no-linux) with_linux=no ;;
	--linux-arm64) linux_arches=(x86_64 arm64) ;;
	--no-publish) publish=no ;;
	-h | --help)
		sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "release.sh: unknown argument \"$1\"" >&2
		exit 2
		;;
	esac
	shift
done

# ── host platform ────────────────────────────────────────────────────────────
case "$(uname -s)" in
Darwin) HOST_OS=macos ;;
Linux) HOST_OS=linux ;;
*)
	echo "release.sh: cannot build releases on $(uname -s)." >&2
	exit 1
	;;
esac
HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
amd64) HOST_ARCH=x86_64 ;;
aarch64) HOST_ARCH=arm64 ;;
esac
HOST_PLATFORM="${HOST_OS}_${HOST_ARCH}"

# ── clear previous release artifacts ─────────────────────────────────────────
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
echo "Cleared previous release artifacts."

# ── host builds ──────────────────────────────────────────────────────────────
mkdir -p "$RELEASE_DIR/$HOST_PLATFORM/python" "$RELEASE_DIR/$HOST_PLATFORM/rust"

echo "Building Python for $HOST_PLATFORM ..."
"$ROOT_DIR/build_py.sh"
mv "$ROOT_DIR/note" "$RELEASE_DIR/$HOST_PLATFORM/python/note"
if [ -d "$ROOT_DIR/_internal" ]; then
	mv "$ROOT_DIR/_internal" "$RELEASE_DIR/$HOST_PLATFORM/python/_internal"
fi

echo "Building Rust for $HOST_PLATFORM ..."
"$ROOT_DIR/build_rs.sh"
mv "$ROOT_DIR/note" "$RELEASE_DIR/$HOST_PLATFORM/rust/note"

PLATFORMS=("$HOST_PLATFORM")

# ── linux cross-builds ───────────────────────────────────────────────────────
# On a Linux host the native build above already covers it; elsewhere the
# artifacts come out of docker, and a release without them is still valid.
if [ "$HOST_OS" != linux ] && [ "$with_linux" != no ]; then
	if docker info >/dev/null 2>&1; then
		for a in "${linux_arches[@]}"; do
			"$ROOT_DIR/build_linux.sh" --arch "$a" --out "$RELEASE_DIR/linux_$a"
			PLATFORMS+=("linux_$a")
		done
	elif [ "$with_linux" = yes ]; then
		echo "release.sh: --linux was asked for, but the docker daemon is not running." >&2
		exit 1
	else
		echo "release.sh: docker is not running — skipping the Linux builds." >&2
		echo "release.sh: this release will have no Linux archives. Start docker and" >&2
		echo "release.sh: re-run, or pass --no-linux to silence this." >&2
	fi
fi

# ── package ──────────────────────────────────────────────────────────────────
ASSETS=()

package() {
	local platform=$1 variant=$2
	local dir="$RELEASE_DIR/$platform/$variant"
	[ -d "$dir" ] || return 0
	[ -f "$dir/note" ] || {
		echo "release.sh: $dir has no note executable" >&2
		exit 1
	}

	cp "$ROOT_DIR/install.sh" "$ROOT_DIR/uninstall.sh" "$dir/"
	chmod +x "$dir/install.sh" "$dir/uninstall.sh"
	cp "$ROOT_DIR/LICENSE" "$dir/LICENSE"
	case "$platform" in
	macos_*) cp "$ROOT_DIR/doc/installation/README.txt" "$dir/README.txt" ;;
	linux_*) cp "$ROOT_DIR/doc/installation/README.linux.txt" "$dir/README.txt" ;;
	esac

	local zip_name="dot_note_${variant}_v${VERSION}_${platform}.zip"
	local zip_path="$RELEASE_DIR/$zip_name"
	rm -f "$zip_path"
	(cd "$dir" && zip -q -r -9 "$zip_path" .)
	ASSETS+=("$zip_path")
	echo "Created archive: $zip_name"
}

for platform in "${PLATFORMS[@]}"; do
	package "$platform" python
	package "$platform" rust
done

# ── checksums ────────────────────────────────────────────────────────────────
# get.sh, get.ps1 and `note update` check the download against these before
# installing it. A release without them installs unverified.
if command -v sha256sum &>/dev/null; then
	SHA=(sha256sum)
else
	SHA=(shasum -a 256)
fi
SHA256SUMS_PATH="$RELEASE_DIR/SHA256SUMS"
NAMES=()
for a in "${ASSETS[@]}"; do NAMES+=("$(basename "$a")"); done
(cd "$RELEASE_DIR" && "${SHA[@]}" "${NAMES[@]}" >SHA256SUMS)
echo "Created checksums: SHA256SUMS"

echo ""
echo "Release v$VERSION built in $RELEASE_DIR:"
for n in "${NAMES[@]}"; do echo "  $n"; done

if [ "$publish" = no ]; then
	echo ""
	echo "Skipping publish (--no-publish). To publish:"
	echo "  ./release_gh.sh v$VERSION $RELEASE_DIR/*.zip $SHA256SUMS_PATH"
	exit 0
fi

"$ROOT_DIR/release_gh.sh" "v${VERSION}" "${ASSETS[@]}" "$SHA256SUMS_PATH"
