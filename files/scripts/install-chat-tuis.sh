#!/usr/bin/env bash
# Terminal chat clients: nchat (Telegram) from its upstream release, verified
# against the release's sha256sums; zulip-terminal as a uv tool.
set -euo pipefail

# Resolve the latest tag from the releases/latest redirect (no API rate limit).
tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/d99kris/nchat/releases/latest)"
tag="${tag##*/}"
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

# Catppuccin Mocha theme for zulip-term, which only loads its built-in themes
zt="$(echo /usr/lib/uv-tools/zulip-term/lib/python3.*/site-packages/zulipterminal)"
install -m644 "$(dirname "$0")/zulip-term/catppuccin_mocha.py" "$zt/themes/"
sed -i \
  -e 's/^from zulipterminal.themes import gruvbox_dark, /from zulipterminal.themes import catppuccin_mocha, gruvbox_dark, /' \
  -e 's/^    "gruvbox_dark": gruvbox_dark,$/    "catppuccin_mocha": catppuccin_mocha,\n    "gruvbox_dark": gruvbox_dark,/' \
  "$zt/config/themes.py"
zulip-term --list-themes 2>/dev/null | grep -q catppuccin_mocha
