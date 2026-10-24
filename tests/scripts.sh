#!/usr/bin/env bash
# Static checks on build scripts.
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
# Unauthenticated GitHub API calls hit shared-runner rate limits and break daily builds
! grep -q 'api.github.com' files/scripts/*.sh && ok "build scripts don't call the GitHub API" || fail "build scripts call api.github.com"
finish
