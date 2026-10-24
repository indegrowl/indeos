#!/usr/bin/env bash
# Build recipes/bastion.yml locally and tag it localhost/bastion:latest.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p "$HOME/.cache/bluebuild"
bluebuild build -B podman --tempdir "$HOME/.cache/bluebuild" recipes/bastion.yml
