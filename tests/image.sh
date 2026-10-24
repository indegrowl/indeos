#!/usr/bin/env bash
# Runtime checks inside a built bastion image. Usage: IMAGE=<ref> tests/image.sh
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh

podman image exists "$IMAGE" || { echo "image $IMAGE not found; run tests/build.sh"; exit 1; }

check_base() {
  assert_grep 'bazzite' /usr/lib/os-release
  assert_pkg rustup mise gcc clang mold python3-devel lua-devel
  assert_no_pkg golang luarocks  # luajit stays: terra-gamescope links libluajit
}

check_base
finish
