#!/usr/bin/env bash
# Static checks: the bastion recipe expands and the repo layout matches the plan.
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh

out="$(mktemp)"
if bluebuild generate -d recipes/bastion.yml -o "$out" >"$out.log" 2>&1; then
  ok "bluebuild generate recipes/bastion.yml"
else
  fail "bluebuild generate recipes/bastion.yml ($(tail -5 "$out.log" | tr '\n' ' '))"
fi

[[ ! -e recipes/indeos.yml ]] && ok "recipes/indeos.yml removed" || fail "recipes/indeos.yml still exists"
[[ ! -e modules ]] && ok "top-level modules/ removed" || fail "top-level modules/ still exists"

matrix="$(sed -n '/recipe:/,/steps:/p' .github/workflows/build.yml)"
grep -qE '^\s*- bastion\.yml' <<<"$matrix" && ok "matrix has bastion.yml" || fail "matrix missing bastion.yml"
grep -qE '^\s*- indeos-remote\.yml' <<<"$matrix" && ok "matrix has indeos-remote.yml" || fail "matrix missing indeos-remote.yml"
! grep -qE '^\s*- indeos\.yml' <<<"$matrix" && ok "matrix has no indeos.yml" || fail "matrix still has indeos.yml"

finish
