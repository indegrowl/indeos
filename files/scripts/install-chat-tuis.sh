#!/usr/bin/env bash
# Terminal chat clients: nchat (Telegram) from its upstream release, verified
# against the release's sha256sums; zulip-terminal as a uv tool.
set -euo pipefail

tag="$(curl -fsSL https://api.github.com/repos/d99kris/nchat/releases/latest | sed -nE 's/.*"tag_name": *"([^"]+)".*/\1/p')"
name="nchat-${tag#v}-linux-x86_64-glibc"
tmp="$(mktemp -d)"
base="https://github.com/d99kris/nchat/releases/download/${tag}"
curl -fsSL -o "$tmp/$name.tar.gz" "$base/$name.tar.gz"
curl -fsSL -o "$tmp/sha256sums.txt" "$base/sha256sums.txt"
(cd "$tmp" && grep " $name.tar.gz\$" sha256sums.txt | sha256sum -c -)
tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
install -Dm755 "$tmp/$name/bin/nchat" /usr/bin/nchat
cp -r "$tmp/$name/share/." /usr/share/
rm -rf "$tmp"

export UV_TOOL_DIR=/usr/lib/uv-tools UV_TOOL_BIN_DIR=/usr/bin UV_PYTHON_DOWNLOADS=never
uv tool install --python 3.13 zulip-term
rm -rf /root/.cache/uv
