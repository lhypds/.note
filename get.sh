#!/bin/sh
#
# Install `note` from its latest GitHub release, on macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh | sh
#
# No toolchain is needed: this downloads the build published for your platform,
# checks it against the release's SHA256SUMS, and copies it into a bin
# directory. By default it installs the rust build, a single self-contained
# binary; --variant python installs the PyInstaller bundle instead.
#
# Options go through the pipe with `sh -s --`:
#
#   curl -fsSL https://raw.githubusercontent.com/lhypds/.note/main/get.sh |
#       sh -s -- --prefix "$HOME/.local"
#
# Env:
#   NOTE_VERSION  version to install, with or without the leading "v"
#   NOTE_VARIANT  build to install: rust (default) or python
#   NOTE_BINDIR   install directory, overriding <prefix>/bin
#   NOTE_LIBDIR   python bundle directory, overriding <prefix>/lib/note
#   NOTE_REPO     "owner/name" to download from (default: lhypds/.note)
#   PREFIX        install prefix; the binary lands in <prefix>/bin
#   GITHUB_TOKEN  lifts GitHub's anonymous rate limit, if you hit it

set -eu

REPO=${NOTE_REPO:-lhypds/.note}
version=${NOTE_VERSION:-}
variant=${NOTE_VARIANT:-rust}
prefix=${PREFIX:-}
bindir=${NOTE_BINDIR:-}
libdir=${NOTE_LIBDIR:-}
tmp=

usage() {
	cat <<'EOF'
Install `note` from its latest GitHub release.

Usage:
  curl -fsSL .../get.sh | sh
  curl -fsSL .../get.sh | sh -s -- [-p <prefix>] [-V <version>] [--variant <v>]

Options:
  -p, --prefix <dir>    install prefix (default: /usr/local when writable,
                        otherwise $HOME/.local)
      --bindir <dir>    install directory, overriding <prefix>/bin
      --libdir <dir>    python bundle directory, overriding <prefix>/lib/note
      --variant <v>     build to install: rust (default) or python
  -V, --version <ver>   version to install (default: the latest release)
  -h, --help            show this help

For a system-wide install on a machine where /usr/local needs root:

  curl -fsSL .../get.sh | sudo sh
EOF
}

die() {
	echo "get.sh: $*" >&2
	exit 1
}

cleanup() {
	[ -z "$tmp" ] || rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

while [ $# -gt 0 ]; do
	case "$1" in
	-p | --prefix)
		[ $# -ge 2 ] || die "$1 needs a value"
		prefix=$2
		shift 2
		;;
	--prefix=*)
		prefix=${1#*=}
		shift
		;;
	--bindir)
		[ $# -ge 2 ] || die "$1 needs a value"
		bindir=$2
		shift 2
		;;
	--bindir=*)
		bindir=${1#*=}
		shift
		;;
	--libdir)
		[ $# -ge 2 ] || die "$1 needs a value"
		libdir=$2
		shift 2
		;;
	--libdir=*)
		libdir=${1#*=}
		shift
		;;
	--variant)
		[ $# -ge 2 ] || die "$1 needs a value"
		variant=$2
		shift 2
		;;
	--variant=*)
		variant=${1#*=}
		shift
		;;
	-V | --version)
		[ $# -ge 2 ] || die "$1 needs a value"
		version=$2
		shift 2
		;;
	--version=*)
		version=${1#*=}
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "get.sh: unknown argument \"$1\"" >&2
		usage >&2
		exit 2
		;;
	esac
done

case "$variant" in
rust | python) ;;
*) die "unknown variant \"$variant\" — use rust or python" ;;
esac

# ── platform ─────────────────────────────────────────────────────────────────
# Release archives are built on macOS, so they are the only ones worth
# downloading; everywhere else, building from source is the shorter road.
os=$(uname -s 2>/dev/null || echo unknown)
case "$os" in
Darwin) ;;
MINGW* | MSYS* | CYGWIN*)
	die "on Windows use the PowerShell installer:
    irm https://raw.githubusercontent.com/$REPO/main/get.ps1 | iex"
	;;
Linux)
	die "no Linux release artifacts are published — build from source instead:
    git clone https://github.com/$REPO.git && cd .note
    ./build_rs.sh   # or ./setup.sh && ./build_py.sh for the python build
    ./install.sh"
	;;
*) die "unsupported operating system \"$os\" — build from source instead: https://github.com/$REPO" ;;
esac

# ── downloader ───────────────────────────────────────────────────────────────
if command -v curl >/dev/null 2>&1; then
	http_get() { curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$1"; }
	http_save() { curl -fsSL -o "$2" "$1"; }
	http_final_url() { curl -fsSLI -o /dev/null -w '%{url_effective}' "$1"; }
elif command -v wget >/dev/null 2>&1; then
	http_get() { wget -qO- ${GITHUB_TOKEN:+--header="Authorization: Bearer $GITHUB_TOKEN"} "$1"; }
	http_save() { wget -qO "$2" "$1"; }
	http_final_url() {
		wget -qS --spider "$1" 2>&1 |
			awk 'tolower($1) == "location:" { url = $2 } END { print url }'
	}
else
	die "neither curl nor wget is installed"
fi

# latest_version reads the version off the redirect that /releases/latest
# serves, which costs no GitHub API request, and falls back to the API.
latest_version() {
	url=$(http_final_url "https://github.com/$REPO/releases/latest" 2>/dev/null || echo)
	case "$url" in
	*/releases/tag/*)
		echo "${url##*/releases/tag/}"
		return 0
		;;
	esac
	http_get "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null |
		sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

if [ -z "$version" ]; then
	version=$(latest_version) || version=
	[ -n "$version" ] || die "could not work out the latest release of $REPO; pass --version <ver>"
fi
version=${version#v}

# ── install directory ────────────────────────────────────────────────────────
# writable reports whether the nearest existing ancestor of a path can be
# written to, so a bindir that does not exist yet is judged by its parent.
writable() {
	dir=$1
	while [ ! -e "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
		dir=$(dirname "$dir")
	done
	[ -w "$dir" ]
}

if [ -z "$prefix" ]; then
	if [ "$(id -u)" = 0 ] || writable /usr/local/bin; then
		prefix=/usr/local
	else
		prefix=${HOME:?HOME is not set; pass --prefix <dir>}/.local
	fi
fi
[ -n "$bindir" ] || bindir=$prefix/bin
[ -n "$libdir" ] || libdir=$prefix/lib/note

not_writable() {
	echo "get.sh: $1 is not writable by this user." >&2
	echo "get.sh: either install it system-wide with root:" >&2
	echo "get.sh:   curl -fsSL https://raw.githubusercontent.com/$REPO/main/get.sh | sudo sh" >&2
	echo "get.sh: or install somewhere you own:" >&2
	echo "get.sh:   curl -fsSL https://raw.githubusercontent.com/$REPO/main/get.sh | sh -s -- --prefix \"\$HOME/.local\"" >&2
	exit 1
}

writable "$bindir" || not_writable "$bindir"
if [ "$variant" = python ]; then
	# The bundle directory is replaced wholesale below, so a --libdir that names
	# a directory full of other things is a mistake worth catching here.
	case "$libdir" in
	"" | / | /bin | /lib | /usr | /usr/bin | /usr/lib | /usr/local | /usr/local/bin | /usr/local/lib | "${HOME:-/nonexistent}")
		die "refusing to install the python bundle into \"$libdir\" — it is replaced wholesale; pass --libdir <dir>/note"
		;;
	esac
	writable "$libdir" || not_writable "$libdir"
fi

# ── download and verify ──────────────────────────────────────────────────────
archive=dot_note_${variant}_v${version}.zip
base=https://github.com/$REPO/releases/download/v$version
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t note-install)

echo "get.sh: downloading note $version ($variant build)..."
http_save "$base/$archive" "$tmp/$archive" ||
	die "no $archive in release v$version of $REPO — see https://github.com/$REPO/releases"

# Releases up to v0.0.22 shipped without checksums; verify when the release has
# them, and say plainly when it does not rather than implying it was checked.
if http_save "$base/SHA256SUMS" "$tmp/SHA256SUMS" 2>/dev/null; then
	want=$(awk -v name="$archive" '{ sub(/^\*/, "", $2); if ($2 == name) { print tolower($1); exit } }' "$tmp/SHA256SUMS")
	[ -n "$want" ] || die "SHA256SUMS of release v$version lists no checksum for $archive"

	if command -v shasum >/dev/null 2>&1; then
		got=$(shasum -a 256 "$tmp/$archive" | cut -d' ' -f1)
	elif command -v sha256sum >/dev/null 2>&1; then
		got=$(sha256sum "$tmp/$archive" | cut -d' ' -f1)
	elif command -v openssl >/dev/null 2>&1; then
		got=$(openssl dgst -sha256 "$tmp/$archive" | awk '{ print $NF }')
	else
		die "none of shasum, sha256sum or openssl is installed; note will not install a release it cannot verify"
	fi
	[ "$(echo "$got" | tr 'A-Z' 'a-z')" = "$want" ] ||
		die "checksum mismatch for $archive: got $got, want $want"
else
	echo "get.sh: release v$version publishes no SHA256SUMS — the download was not verified." >&2
fi

# ── unpack ───────────────────────────────────────────────────────────────────
# The archive holds `note` (plus `_internal/` for the python build) at its top
# level, so it unpacks straight into a staging directory.
stage=$tmp/unpacked
mkdir -p "$stage"
if command -v unzip >/dev/null 2>&1; then
	unzip -q "$tmp/$archive" -d "$stage" || die "could not unpack $archive"
else
	# bsdtar, which is /usr/bin/tar on macOS, reads zip archives too.
	tar -xf "$tmp/$archive" -C "$stage" || die "could not unpack $archive"
fi

bin=$stage/note
[ -f "$bin" ] || die "$archive contains no note executable"

# ── architecture ─────────────────────────────────────────────────────────────
# Read the Mach-O header rather than running the binary, so a release built for
# another architecture reports the reason instead of "Bad CPU type".
header=$(od -An -tx1 -N8 "$bin" 2>/dev/null | tr -d ' \n')
case "$header" in
cafebabe* | cafebabf* | bebafeca*) bin_arch=universal ;; # fat binary: holds several
cffaedfe0c000001*) bin_arch=arm64 ;;
cffaedfe07000001*) bin_arch=x86_64 ;;
7f454c46*) die "release v$version contains a Linux build of note, but this machine is macOS" ;;
*) bin_arch=unknown ;;
esac

arch=$(uname -m 2>/dev/null || echo unknown)
case "$arch" in
amd64) arch=x86_64 ;;
aarch64) arch=arm64 ;;
esac

if [ "$bin_arch" != universal ] && [ "$bin_arch" != unknown ] && [ "$bin_arch" != "$arch" ]; then
	die "release v$version is built for $bin_arch, but this machine is $arch.
    Release archives are built on Apple silicon and do not run on $arch Macs.
    Build from source instead:
      git clone https://github.com/$REPO.git && cd .note
      ./build_rs.sh   # or ./setup.sh && ./build_py.sh for the python build
      ./install.sh"
fi

# ── install ──────────────────────────────────────────────────────────────────
mkdir -p "$bindir" || die "could not create $bindir"

if [ "$variant" = rust ]; then
	# Single self-contained binary. Copy in beside the target and rename, so an
	# interrupted install cannot leave a half-written note behind, and a running
	# one is replaced rather than rewritten.
	chmod 0755 "$bin"
	cp "$bin" "$bindir/.note.new" || die "could not write to $bindir"
	mv "$bindir/.note.new" "$bindir/note" || die "could not install $bindir/note"
	target=$bindir/note
else
	# PyInstaller onedir bundle: the executable needs its sibling _internal/, so
	# the whole bundle is installed and only a symlink goes on the PATH.
	[ -d "$stage/_internal" ] || die "$archive is not a python bundle — it has no _internal/ directory"
	rm -rf "$libdir" || die "could not replace $libdir"
	mkdir -p "$libdir" || die "could not create $libdir"
	cp -R "$stage/." "$libdir/" || die "could not write to $libdir"
	chmod 0755 "$libdir/note"

	rm -f "$bindir/note"
	ln -s "$libdir/note" "$bindir/note" || die "could not install $bindir/note"
	echo "get.sh: installed bundle $libdir"
	target=$bindir/note
fi

# Gatekeeper quarantines archives that arrive through a browser; one that came
# down this pipe is not quarantined, but clear the flag in case it was. It is
# usually absent, and `xattr -d` says so by failing.
if command -v xattr >/dev/null 2>&1; then
	xattr -d com.apple.quarantine "$target" 2>/dev/null || true
fi

echo "get.sh: installed $target ($("$target" --version))"

# ── .noterc ──────────────────────────────────────────────────────────────────
# $USER is not always exported (containers, cron, non-login shells), and `sudo
# sh` would otherwise write the config into root's home.
install_user=${SUDO_USER:-${USER:-$(id -un)}}
user_home=$(eval echo "~$install_user")
noterc=$user_home/.noterc
if [ ! -f "$noterc" ]; then
	echo "notePath=" >"$noterc"
	[ -n "${SUDO_USER-}" ] && chown "$SUDO_USER" "$noterc" 2>/dev/null
	echo "get.sh: created $noterc — set notePath to your note directories, e.g."
	echo "        notePath=~/Dropbox/Note;~/Dropbox/Note.video;"
fi

case ":${PATH-}:" in
*":$bindir:"*) ;;
*)
	echo
	echo "warning: $bindir is not on your PATH; add it with"
	echo "  export PATH=\"$bindir:\$PATH\""
	;;
esac

if ! command -v fzf >/dev/null 2>&1; then
	echo
	echo "next: install fzf for \`note search\`, \`note open\` and \`note delete\`"
	echo "      (run: brew install fzf)"
fi
