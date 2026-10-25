#!/usr/bin/env bash
# Build tgt (Telegram TUI), which Fedora doesn't package. TDLib is linked statically.
# crates.io's newest tgt is from 2024, so build from the upstream git tag.
set -euo pipefail
TGT_TAG=v1.0.0-rc1
dnf -y install cargo git gcc-c++ cmake pkgconf-pkg-config openssl-devel alsa-lib-devel opus-devel \
  libcxx-devel libcxx-static libcxxabi-devel libcxxabi-static
cargo install --locked --root /tmp/tgt --git https://github.com/FedericoBruzzone/tgt --tag "$TGT_TAG" \
  --features download-tdlib,static tgt
mkdir -p /out
cp /tmp/tgt/bin/tgt /out/
