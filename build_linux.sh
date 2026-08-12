#!/bin/bash
#
# Cross-build the Linux artifacts of `note` in Docker, from any Docker host.
#
#   ./build_linux.sh                          # both variants, x86_64
#   ./build_linux.sh --variant rust           # rust only
#   ./build_linux.sh --arch arm64             # aarch64
#   ./build_linux.sh --out /tmp/linux_build   # somewhere other than release/
#
# The rust build is statically linked against musl, so the binary runs on any
# distribution. The python build is a PyInstaller bundle against the glibc of
# an old-stable Debian, so it needs glibc 2.31 or newer (Debian 11, Ubuntu
# 20.04, RHEL 9 and up).
#
# Sources are copied into the container rather than built in the bind mount, so
# a Linux build never overwrites the host's own `note`, `_internal` or
# `rust/target`.
#
# Env:
#   NOTE_LINUX_RUST_IMAGE  rust builder image (default: rust:1-alpine)
#   NOTE_LINUX_PY_IMAGE    python builder image (default: python:3.11-bullseye)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

RUST_IMAGE=${NOTE_LINUX_RUST_IMAGE:-rust:1-alpine}
PY_IMAGE=${NOTE_LINUX_PY_IMAGE:-python:3.11-bullseye}

variant=both
arch=x86_64
out=

usage() {
	sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
	case "$1" in
	--variant)
		variant=${2:?--variant needs a value}
		shift 2
		;;
	--variant=*)
		variant=${1#*=}
		shift
		;;
	--arch)
		arch=${2:?--arch needs a value}
		shift 2
		;;
	--arch=*)
		arch=${1#*=}
		shift
		;;
	--out)
		out=${2:?--out needs a value}
		shift 2
		;;
	--out=*)
		out=${1#*=}
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "build_linux.sh: unknown argument \"$1\"" >&2
		usage >&2
		exit 2
		;;
	esac
done

case "$variant" in
rust | python | both) ;;
*)
	echo "build_linux.sh: unknown variant \"$variant\" — use rust, python or both" >&2
	exit 2
	;;
esac

case "$arch" in
x86_64 | amd64)
	arch=x86_64
	platform=linux/amd64
	triple=x86_64-unknown-linux-musl
	;;
arm64 | aarch64)
	arch=arm64
	platform=linux/arm64
	triple=aarch64-unknown-linux-musl
	;;
*)
	echo "build_linux.sh: unknown arch \"$arch\" — use x86_64 or arm64" >&2
	exit 2
	;;
esac

[ -n "$out" ] || out="$ROOT_DIR/release/linux_$arch"

if ! command -v docker >/dev/null 2>&1; then
	echo "Error: docker is not installed — it is what builds the Linux artifacts." >&2
	echo "       Install Docker Desktop (https://docker.com), or build on a Linux" >&2
	echo "       machine with ./build_rs.sh / ./build_py.sh instead." >&2
	exit 1
fi
if ! docker info >/dev/null 2>&1; then
	echo "Error: the docker daemon is not running." >&2
	exit 1
fi

# The host arch runs natively; the other one goes through qemu, which docker
# only has when binfmt emulation is installed.
host_arch=$(uname -m)
case "$host_arch" in
amd64) host_arch=x86_64 ;;
aarch64) host_arch=arm64 ;;
esac
if [ "$host_arch" != "$arch" ]; then
	echo "Note: building linux/$arch on a $host_arch host — this runs under qemu emulation and is slow."
fi

build_rust() {
	local dest="$out/rust"
	mkdir -p "$dest"
	echo "Building rust for linux/$arch ($triple) ..."

	# build-base and perl are what the `ring` crate (via ureq's TLS) needs to
	# compile its C and assembly on alpine.
	docker run --rm \
		--platform "$platform" \
		-v "$ROOT_DIR:/src:ro" \
		-v "$dest:/out" \
		-v note-cargo-registry:/usr/local/cargo/registry \
		-v "note-cargo-target-$arch:/cargo-target" \
		"$RUST_IMAGE" \
		sh -eu -c "
			apk add --no-cache build-base perl >/dev/null
			rustup target add $triple >/dev/null 2>&1 || true
			mkdir -p /work
			cp /src/VERSION /work/VERSION
			cp -R /src/rust /work/rust
			rm -rf /work/rust/target
			cd /work/rust
			export CARGO_TARGET_DIR=/cargo-target
			NOTE_RUST_TARGET=$triple sh build.sh
			strip /work/note 2>/dev/null || true
			cp /work/note /out/note
			chmod 0755 /out/note
		"
	echo "Built: $dest/note"
}

build_python() {
	local dest="$out/python"
	mkdir -p "$dest"
	echo "Building python for linux/$arch ..."

	docker run --rm \
		--platform "$platform" \
		-v "$ROOT_DIR:/src:ro" \
		-v "$dest:/out" \
		"$PY_IMAGE" \
		sh -eu -c '
			mkdir -p /work
			cp /src/note.py /src/VERSION /src/requirements.txt /src/build_py.sh /work/
			cp -R /src/commands /work/commands
			find /work -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
			cd /work
			python -m venv /venv
			/venv/bin/pip install -q --upgrade pip
			/venv/bin/pip install -q -r requirements.txt
			PYTHON_BIN=/venv/bin/python bash build_py.sh
			cp /work/note /out/note
			rm -rf /out/_internal
			cp -R /work/_internal /out/_internal
			chmod 0755 /out/note
		'
	echo "Built: $dest/note (+ _internal/)"
}

if [ "$variant" = rust ] || [ "$variant" = both ]; then
	build_rust
fi
if [ "$variant" = python ] || [ "$variant" = both ]; then
	build_python
fi

echo "Linux artifacts in $out"
