#!/bin/bash
# Build Rust Pulse module with clippy checks

RUST_DIR="$(dirname "$0")/../../../rust_pulse"

if [ ! -d "$RUST_DIR" ]; then
    echo "Error: rust_pulse directory not found at $RUST_DIR"
    exit 1
fi

cd "$RUST_DIR" || exit 1

echo "=== Clippy Check ==="
cargo clippy -- -D warnings

echo ""
echo "=== Cargo Build ==="
cargo build
