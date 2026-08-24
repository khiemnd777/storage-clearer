#!/bin/bash

set -u
set -o pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
SCRIPT_PATH="${PROJECT_DIR}/storage-clearer.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

/bin/bash -n "${SCRIPT_PATH}" || fail "bash syntax"
pass "bash syntax"

SC_SKIP_MAIN=1
export SC_SKIP_MAIN
# shellcheck source=../storage-clearer.sh
source "${SCRIPT_PATH}"

package_b="$(sc_package_actions B)" || fail "Package B exists"
sc_contains_action "${package_b}" simulator-old-runtimes || fail "Package B includes old runtimes"
sc_contains_action "${package_b}" dev-caches || fail "Package B includes developer caches"
sc_contains_action "${package_b}" docker-build-cache || fail "Package B includes Docker build cache"
if sc_contains_action "${package_b}" docker-unused-volumes; then
  fail "Package B must exclude Docker volumes"
fi
pass "Package B policy"

package_b_count="$(printf '%s\n' "${package_b}" | awk 'NF {count++} END {print count + 0}')"
[ "${package_b_count}" -eq 6 ] || fail "Package B action count changed unexpectedly"
pass "Package B action count"

sc_is_allowed_cache_target "${SC_USER_HOME}/.npm/_cacache" || fail "known cache is allowed"
if sc_is_allowed_cache_target "${SC_GO_MODULE_CACHE}"; then
  fail "read-only Go module cache must use go clean, never direct rm"
fi
if sc_is_allowed_cache_target "${SC_USER_HOME}"; then
  fail "user home must never be an allowed cache target"
fi
if sc_is_allowed_cache_target "/"; then
  fail "filesystem root must never be an allowed cache target"
fi
if sc_is_allowed_cache_target "${SC_USER_HOME}/Works"; then
  fail "Works must never be an allowed cache target"
fi
pass "cache allowlist guard"

[ "$(sc_runtime_device_key 18.3.1)" = "com.apple.CoreSimulator.SimRuntime.iOS-18-3" ] || fail "runtime identifier conversion"
pass "runtime identifier conversion"

for action in ${SC_EXECUTABLE_ACTIONS[*]}; do
  sc_is_executable_action "${action}" || fail "registered action is executable: ${action}"
done
if sc_is_executable_action codex-sessions; then
  fail "Codex sessions must remain report-only"
fi
pass "executable action registry"

help_output="$(SC_SKIP_MAIN=0 /bin/bash "${SCRIPT_PATH}" help)" || fail "help command"
printf '%s' "${help_output}" | grep -q 'audit' || fail "help mentions audit"
printf '%s' "${help_output}" | grep -q 'exact typed approval phrase' || fail "help documents approval gate"
pass "help output"

spinner_output="$(SC_NO_ANIMATION=1 sc_spinner_start 'test phase' 2>&1; SC_NO_ANIMATION=1 sc_spinner_stop done 2>&1)"
printf '%s' "${spinner_output}" | grep -q '\[done\] test phase' || fail "static spinner fallback"
pass "spinner fallback"

printf 'All tests passed. No cleanup commands were executed.\n'
