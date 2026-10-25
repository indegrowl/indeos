#!/usr/bin/env bash
# Build wiremix (PipeWire mixer TUI), which Fedora doesn't package.
set -euo pipefail
WIREMIX_VERSION=0.11.0
dnf -y install cargo clang pipewire-devel
cargo install --locked --root /tmp/wiremix wiremix --version "$WIREMIX_VERSION"
mkdir -p /out
cp /tmp/wiremix/bin/wiremix /out/
