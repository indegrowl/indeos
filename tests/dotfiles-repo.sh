#!/usr/bin/env bash
# The dotfiles repo must not drop repo meta files (LICENSE, README.md) into ~
# when chezmoi applies it on first login.
# Usage: DOTFILES_REPO=<url-or-path> tests/dotfiles-repo.sh
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh

repo="${DOTFILES_REPO:-https://github.com/indegrowl/dotfiles.git}"
if chezmoi --version >/dev/null 2>&1; then cz=(chezmoi); else cz=(mise x chezmoi@latest -- chezmoi); fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
git clone -q "$repo" "$tmp/src" || { fail "clone $repo"; finish; }
mkdir -p "$tmp/home"; : > "$tmp/chezmoi.toml"
czr() { "${cz[@]}" --source "$tmp/src" --destination "$tmp/home" --config "$tmp/chezmoi.toml" "$@"; }

managed="$(czr managed 2>&1)" || { fail "chezmoi managed errored: $managed"; finish; }
[[ -z "$managed" ]] && ok "chezmoi manages nothing unexpected" || fail "chezmoi would manage: $(echo $managed)"
czr apply >/dev/null 2>&1 || fail "chezmoi apply errored"
[[ -z "$(ls -A "$tmp/home")" ]] && ok "apply leaves home empty" || fail "apply created: $(ls -A "$tmp/home" | tr '\n' ' ')"

finish
