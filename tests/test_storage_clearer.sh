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

if sc_contains_action "${package_b}" time-machine-snapshots; then
  fail "Package B must exclude Time Machine snapshots"
fi
if sc_contains_action "${package_b}" ai-assistant-caches; then
  fail "Package B must exclude AI assistant caches"
fi
pass "read-only categories excluded from Package B"

for cache_target in \
  "${SC_USER_HOME}/.npm/_cacache" \
  "${SC_USER_HOME}/Library/Caches/pip" \
  "${SC_USER_HOME}/Library/Caches/node-gyp" \
  "${SC_USER_HOME}/Library/Caches/ms-playwright-go"; do
  sc_is_allowed_cache_target "${cache_target}" || fail "known cache is allowed: ${cache_target}"
  cache_is_audited=0
  for audited_target in "${SC_DEV_CACHE_TARGETS[@]}"; do
    if [ "${audited_target}" = "${cache_target}" ]; then
      cache_is_audited=1
      break
    fi
  done
  [ "${cache_is_audited}" -eq 1 ] || fail "cleanup cache must also be included in audit estimates: ${cache_target}"
done
if sc_is_allowed_cache_target "${SC_GO_MODULE_CACHE}"; then
  fail "read-only Go module cache must use go clean, never direct rm"
fi
if sc_is_allowed_cache_target "${SC_USER_HOME}/Library/Caches/Codex"; then
  fail "Codex cache must remain report-only"
fi
if sc_is_allowed_cache_target "${SC_USER_HOME}/Library/Caches/com.apple.python"; then
  fail "unclassified application cache must not enter the allowlist"
fi
if sc_is_allowed_cache_target "${SC_USER_HOME}/Library/Caches/4kdownload.com"; then
  fail "download application cache must not enter the allowlist"
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
if sc_is_executable_action time-machine-snapshots; then
  fail "Time Machine snapshots must remain report-only"
fi
if sc_is_executable_action ai-assistant-caches; then
  fail "AI assistant caches must remain report-only"
fi
pass "executable action registry"

tm_fixture='Snapshots for volume group containing disk /:
com.apple.TimeMachine.2026-08-22-133354.local
not-a-snapshot
com.apple.os.update-1234567890
com.apple.TimeMachine.malformed.local
com.apple.TimeMachine.2026-08-23-133836.local'
tm_parsed="$(printf '%s\n' "${tm_fixture}" | sc_parse_tm_snapshot_output)"
tm_count="$(printf '%s\n' "${tm_parsed}" | awk 'NF {count++} END {print count + 0}')"
[ "${tm_count}" -eq 2 ] || fail "Time Machine parser keeps only Time Machine snapshot names"
printf '%s\n' "${tm_parsed}" | grep -q '^com\.apple\.TimeMachine\.2026-08-22-133354\.local$' || fail "first Time Machine snapshot parsed"
[ "$(sc_tm_snapshot_timestamp 'com.apple.TimeMachine.2026-08-22-133354.local')" = "2026-08-22 13:33:54" ] || fail "snapshot timestamp formatting"
[ "$(printf 'Snapshots for disk /:\n' | sc_parse_tm_snapshot_output | awk 'NF {count++} END {print count + 0}')" -eq 0 ] || fail "empty snapshot list"
pass "Time Machine snapshot parser"

[ "$(sc_action_risk time-machine-snapshots)" = "HIGH" ] || fail "snapshot risk is HIGH"
[ "$(sc_action_option time-machine-snapshots)" = "Manual review" ] || fail "snapshot action is manual review"
[ "$(sc_action_option ai-assistant-caches)" = "Manual review" ] || fail "AI caches are manual review"
pass "read-only reason matrix policy"

help_output="$(SC_SKIP_MAIN=0 /bin/bash "${SCRIPT_PATH}" help)" || fail "help command"
printf '%s' "${help_output}" | grep -q 'audit' || fail "help mentions audit"
printf '%s' "${help_output}" | grep -q 'exact typed approval phrase' || fail "help documents approval gate"
pass "help output"

spinner_output="$(SC_NO_ANIMATION=1 sc_spinner_start 'test phase' 2>&1; SC_NO_ANIMATION=1 sc_spinner_stop done 2>&1)"
printf '%s' "${spinner_output}" | grep -q '\[done\] test phase' || fail "static spinner fallback"
pass "spinner fallback"

printf 'All tests passed. No cleanup commands were executed.\n'
