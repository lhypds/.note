#!/bin/sh

set -eu

# NOTE_RUST_TARGET builds for an explicit target triple, which is how the Linux
# artifacts are cross-built inside a container. Cargo then writes the binary to
# <target-dir>/<triple>/release instead of <target-dir>/release.
target_dir=${CARGO_TARGET_DIR:-target}
out=${NOTE_BIN_OUT:-../note}

if [ -n "${NOTE_RUST_TARGET:-}" ]; then
	cargo build --release --target "$NOTE_RUST_TARGET"
	cp "$target_dir/$NOTE_RUST_TARGET/release/note" "$out"
else
	cargo build --release
	cp "$target_dir/release/note" "$out"
fi
