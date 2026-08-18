#!/bin/bash
#
# Build and package `note` for every platform this machine can produce, then
# hand the archives to release_gh.sh.
#
#   ./release.sh                   # host platform + linux x86_64 and arm64
#   ./release.sh --no-linux        # host platform only
#   ./release.sh --linux-x86-only  # skip the linux arm64 archives
#   ./release.sh --no-publish      # build and zip, but do not touch GitHub
#
# VERSION is checked against the latest GitHub release first. When they are
# equal, you are asked which segment to bump, and the new VERSION is committed
# and pushed. --no-publish skips that check along with the publish step.
#
# Archives are named dot_note_rust_v<version>_<os>_<arch>.zip, which is what
# get.sh, get.ps1 and `note update` look for. The "rust" token is kept from
# when there was a second build to tell apart, so the names stay stable across
# releases.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$ROOT_DIR/release"

with_linux=auto
publish=yes
# arm64 is the native one on an Apple silicon dev box; x86_64 goes through
# qemu and is the slow half of the build.
linux_arches=(x86_64 arm64)

while [ $# -gt 0 ]; do
	case "$1" in
	--linux) with_linux=yes ;;
	--no-linux) with_linux=no ;;
	--linux-x86-only) linux_arches=(x86_64) ;;
	--no-publish) publish=no ;;
	-h | --help)
		sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "release.sh: unknown argument \"$1\"" >&2
		exit 2
		;;
	esac
	shift
done

# ── version ──────────────────────────────────────────────────────────────────
normalize_version() {
	local v="$1"
	v="${v#v}"
	v="$(printf '%s' "$v" | tr -d '[:space:]')"
	printf '%s' "$v"
}

# Prints 1, -1 or 0 for lhs greater than, less than or equal to rhs.
version_compare() {
	local lhs="$1"
	local rhs="$2"
	local IFS='.'
	local -a a_parts b_parts
	local max_len i a_seg b_seg

	read -r -a a_parts <<<"$lhs"
	read -r -a b_parts <<<"$rhs"

	max_len="${#a_parts[@]}"
	if [ "${#b_parts[@]}" -gt "$max_len" ]; then
		max_len="${#b_parts[@]}"
	fi

	for ((i = 0; i < max_len; i++)); do
		a_seg="${a_parts[i]:-0}"
		b_seg="${b_parts[i]:-0}"
		if ! [[ "$a_seg" =~ ^[0-9]+$ ]] || ! [[ "$b_seg" =~ ^[0-9]+$ ]]; then
			echo "Error: VERSION contains non-numeric segments ($lhs vs $rhs)." >&2
			exit 1
		fi

		if ((10#$a_seg > 10#$b_seg)); then
			echo 1
			return
		fi
		if ((10#$a_seg < 10#$b_seg)); then
			echo -1
			return
		fi
	done

	echo 0
}

# Asks which segment to bump, counting from the right, and zeroes everything
# after it: bumping the second-last of 0.0.25 gives 0.1.0.
bump_version_interactive() {
	local current="$1"
	local IFS='.'
	local -a parts
	local count choice idx i

	read -r -a parts <<<"$current"
	count="${#parts[@]}"
	if [ "$count" -eq 0 ]; then
		echo "Error: invalid VERSION '$current'." >&2
		exit 1
	fi

	for i in "${parts[@]}"; do
		if ! [[ "$i" =~ ^[0-9]+$ ]]; then
			echo "Error: VERSION contains non-numeric segments ($current)." >&2
			exit 1
		fi
	done

	read -r -p "VERSION $current equals latest release. Which segment to bump from right? [1=last, 2=second last, ...] (default: 1): " choice
	choice="${choice:-1}"
	if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
		echo "Error: invalid segment selection '$choice'." >&2
		exit 1
	fi

	idx=$((count - choice))
	parts[idx]=$((10#${parts[idx]} + 1))
	for ((i = idx + 1; i < count; i++)); do
		parts[i]=0
	done

	local result="${parts[0]}"
	for ((i = 1; i < count; i++)); do
		result+=".${parts[i]}"
	done
	printf '%s' "$result"
}

prepare_version_for_release() {
	if [ ! -f "$ROOT_DIR/VERSION" ]; then
		echo "Error: VERSION file not found." >&2
		exit 1
	fi

	if ! command -v gh &>/dev/null; then
		echo "Error: GitHub CLI (gh) is required." >&2
		exit 1
	fi
	if ! gh auth status &>/dev/null; then
		echo "Error: gh is not authenticated. Run: gh auth login" >&2
		exit 1
	fi

	local current draft_tag draft_tags latest_tag latest cmp new_version branch
	current="$(normalize_version "$(cat "$ROOT_DIR/VERSION")")"
	if [ -z "$current" ]; then
		echo "Error: VERSION file is empty." >&2
		exit 1
	fi

	if ! draft_tags="$(gh release list --limit 1000 --json tagName,isDraft \
		--jq '.[] | select(.isDraft) | .tagName' 2>/dev/null)"; then
		echo "Error: unable to check GitHub for draft releases." >&2
		exit 1
	fi
	if [ -n "$draft_tags" ]; then
		echo "Warning: GitHub draft release(s) found:"
		while IFS= read -r draft_tag; do
			echo "  - $draft_tag"
		done <<<"$draft_tags"
		echo "Review, publish, or delete the draft release(s) before continuing."
		exit 1
	fi

	latest_tag="$(gh release view --json tagName --jq '.tagName' 2>/dev/null || true)"
	if [ "$latest_tag" = "null" ]; then
		latest_tag=""
	fi

	if [ -z "$latest_tag" ]; then
		echo "No existing GitHub release found. Releasing VERSION $current."
		return
	fi

	latest="$(normalize_version "$latest_tag")"
	cmp="$(version_compare "$current" "$latest")"

	if [ "$cmp" -gt 0 ]; then
		echo "VERSION $current is greater than latest release $latest. Continue releasing."
		return
	fi

	if [ "$cmp" -lt 0 ]; then
		echo "Error: VERSION $current is lower than latest release $latest." >&2
		exit 1
	fi

	new_version="$(bump_version_interactive "$current")"
	printf '%s\n' "$new_version" >"$ROOT_DIR/VERSION"

	git -C "$ROOT_DIR" add "$ROOT_DIR/VERSION"
	git -C "$ROOT_DIR" commit -m "$new_version"

	branch="$(git -C "$ROOT_DIR" branch --show-current 2>/dev/null || true)"
	if [ -n "$branch" ]; then
		git -C "$ROOT_DIR" push origin "$branch"
	else
		git -C "$ROOT_DIR" push
	fi

	echo "VERSION bumped to $new_version, committed, and pushed."
}

# --no-publish is a local build, so it neither reads GitHub nor moves VERSION on.
if [ "$publish" = yes ]; then
	prepare_version_for_release
fi

VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
if [ -z "$VERSION" ]; then
	echo "release.sh: VERSION file is empty." >&2
	exit 1
fi

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

# ── host build ───────────────────────────────────────────────────────────────
mkdir -p "$RELEASE_DIR/$HOST_PLATFORM/rust"

echo "Building for $HOST_PLATFORM ..."
"$ROOT_DIR/build.sh"
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
	local platform=$1
	local dir="$RELEASE_DIR/$platform/rust"
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

	local zip_name="dot_note_rust_v${VERSION}_${platform}.zip"
	local zip_path="$RELEASE_DIR/$zip_name"
	rm -f "$zip_path"
	(cd "$dir" && zip -q -r -9 "$zip_path" .)
	ASSETS+=("$zip_path")
	echo "Created archive: $zip_name"
}

for platform in "${PLATFORMS[@]}"; do
	package "$platform"
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
