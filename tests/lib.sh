# Shared assertion helpers for the bastion tests. Source, don't execute.
# IMAGE is the image under test (used by run_in_image and the assert_* helpers).

IMAGE="${IMAGE:-localhost/bastion:latest}"
FAILED=0

ok()   { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; FAILED=1; }

finish() {
  if [[ $FAILED -eq 0 ]]; then echo "ALL OK"; exit 0; fi
  echo "SOME CHECKS FAILED"; exit 1
}

# run_in_image <shell command...>: run a command inside $IMAGE.
run_in_image() {
  podman run --rm --network=none --no-hostname --no-hosts --entrypoint /bin/bash "$IMAGE" -c "$*"
}

# check <description> <shell command>: ok if the command succeeds inside the image.
check() {
  local desc="$1"; shift
  if run_in_image "$*" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi
}

assert_pkg() {
  local missing
  missing="$(run_in_image "for p in $*; do rpm -q --whatprovides \"\$p\" >/dev/null 2>&1 || echo \"\$p\"; done")"
  if [[ -z "$missing" ]]; then ok "packages: $*"; else fail "missing packages: $(echo $missing)"; fi
}

assert_no_pkg() {
  local present
  present="$(run_in_image "for p in $*; do rpm -q \"\$p\" >/dev/null 2>&1 && echo \"\$p\"; done; true")"
  if [[ -z "$present" ]]; then ok "absent packages: $*"; else fail "should be absent: $(echo $present)"; fi
}

assert_file() { check "file exists: $1" "test -e '$1'"; }

assert_grep() { check "grep '$1' in $2" "grep -qE -- '$1' '$2'"; }

# assert_enabled <unit> [system|user]: unit is enabled (system) or globally enabled (user).
assert_enabled() {
  local unit="$1" scope="${2:-system}"
  if [[ "$scope" == user ]]; then
    check "user unit enabled: $unit" "systemctl --global is-enabled '$unit' | grep -qx enabled"
  else
    check "system unit enabled: $unit" "systemctl is-enabled '$unit' 2>/dev/null | grep -qx enabled"
  fi
}

assert_masked() {
  check "masked: $1" "[ \"\$(readlink -f /etc/systemd/system/$1)\" = /dev/null ]"
}
