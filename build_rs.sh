#!/bin/bash

set -euo pipefail

# Check that cargo is installed before attempting to run Rust build
if ! command -v cargo >/dev/null 2>&1; then
	echo "Error: 'cargo' is not installed or not found in PATH."
	echo "Install Rust (which provides cargo) from https://rustup.rs or with your package manager (e.g. 'brew install rust' on macOS)."
	exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$ROOT_DIR/rust"
./build.sh "$@"
