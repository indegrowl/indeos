#!/usr/bin/env bash
# Install the AI coding agents system-wide. They update with image rebuilds.
# Claude Code is deliberately not here: the image is public and it's proprietary.
set -euo pipefail

# hermes-agent needs Python >=3.11,<3.14; Fedora's default is newer, so pin 3.13.
export UV_TOOL_DIR=/usr/lib/uv-tools UV_TOOL_BIN_DIR=/usr/bin UV_PYTHON_DOWNLOADS=never
uv tool install --python 3.13 hermes-agent

npm install -g --prefix /usr @earendil-works/pi-coding-agent

rm -rf /root/.npm /root/.cache/uv
