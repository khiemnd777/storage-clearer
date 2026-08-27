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

SC_DATA_DEVICE='disk"ui-test'
SC_DISK_TOTAL_BYTES=100
SC_DISK_USED_BYTES=60
SC_DISK_FREE_BYTES=40
app_json="$(sc_print_app_json)"
printf '%s\n' "${app_json}" | plutil -convert xml1 -o - - >/dev/null || fail "app JSON contract is valid"
printf '%s\n' "${app_json}" | grep -q '"schemaVersion":1' || fail "app JSON schema version"
printf '%s\n' "${app_json}" | grep -q '"device":"disk\\"ui-test"' || fail "app JSON escaping"
printf '%s\n' "${app_json}" | grep -q '"A":\["docker-stopped-containers"' || fail "app JSON Package A"
printf '%s\n' "${app_json}" | grep -q '"id":"codex-sessions".*"executable":false' || fail "app JSON preserves report-only policy"
pass "native app JSON contract"

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
if sc_contains_action "${package_b}" time-machine-thin; then
  fail "Package B must exclude Time Machine thinning"
fi
if sc_contains_action "${package_b}" ai-assistant-caches; then
  fail "Package B must exclude AI assistant caches"
fi
pass "read-only categories excluded from Package B"

[ "$(sc_size_to_bytes '617.2MB')" = "617200000" ] || fail "decimal Docker size parsing"
[ "$(sc_size_to_bytes '6.172e+08B')" = "617200000" ] || fail "scientific Docker size parsing"
[ "$(sc_size_to_bytes '-6.172e+08B')" = "0" ] || fail "negative Docker size is clamped to zero"
if sc_size_to_bytes 'not-a-size' >/dev/null 2>&1; then
  fail "invalid Docker size must be rejected"
fi
[ "$(sc_docker_size_display '617.2MB (3%)')" = "617.20 MB" ] || fail "Docker percentage suffix formatting"
[ "$(sc_docker_size_display '6.172e+08B')" = "617.20 MB" ] || fail "scientific Docker size formatting"
[ "$(sc_docker_size_display '-6.172e+08B')" = "0 B" ] || fail "negative Docker size formatting"
[ "$(sc_docker_size_display 'unknown')" = "unknown" ] || fail "unknown Docker size remains unknown"
sc_docker_size_is_negative '-6.172e+08B' || fail "negative Docker size detection"
if sc_docker_size_is_negative '617.2MB'; then
  fail "positive Docker size must not be marked negative"
fi

docker_fixture_state="$(
  docker() {
    printf '%s\n' \
      'Images|21|4|21.13GB|-6.172e+08B (-3%)' \
      'Containers|8|3|1.2GB|600MB (50%)' \
      'Local Volumes|5|4|900MB|100MB (11%)' \
      'Build Cache|12|0|3GB|2.5GB (83%)'
  }
  SC_DOCKER_READY=0
  sc_collect_docker
  printf '%s|%s|%s|%s' \
    "${SC_DOCKER_READY}" \
    "${SC_DOCKER_IMAGES_TOTAL}" \
    "${SC_DOCKER_IMAGES_RECLAIM}" \
    "$(sc_action_estimate docker-unused-images)"
)"
[ "${docker_fixture_state}" = "1|21.13GB|-6.172e+08B|0 B" ] || fail "Docker collector normalizes the Issue #2 fixture"

SC_DOCKER_IMAGES_TOTAL="21.13GB"
SC_DOCKER_IMAGES_RECLAIM="-6.172e+08B"
[ "$(sc_action_estimate docker-unused-images)" = "0 B" ] || fail "negative Docker estimate is zero"
[ "$(sc_action_estimate_bytes docker-unused-images)" = "0" ] || fail "negative Docker estimate contributes zero bytes"
docker_negative_explanation="$(sc_explain_action docker-unused-images)"
printf '%s\n' "${docker_negative_explanation}" | grep -q 'Estimate: 0 B' || fail "negative Docker estimate is human-readable"
printf '%s\n' "${docker_negative_explanation}" | grep -q 'Evidence: Images total 21.13 GB; reclaimable 0 B\.' || fail "Docker evidence uses normalized sizes"
printf '%s\n' "${docker_negative_explanation}" | grep -q 'invalid negative reclaimable value; treated as zero' || fail "Docker negative anomaly is explained"
if printf '%s\n' "${docker_negative_explanation}" | grep -Eq -- '-[0-9]|[eE][+-][0-9]'; then
  fail "Docker explanation must not expose negative or scientific sizes"
fi
docker_negative_plan="$(sc_show_plan docker-unused-images)"
printf '%s\n' "${docker_negative_plan}" | grep -q 'Approximate package total: 0 B' || fail "negative Docker size cannot reduce package total"
if printf '%s\n' "${docker_negative_plan}" | grep -Eq -- 'estimate -|total: -|[eE][+-][0-9]'; then
  fail "Docker plan must not expose negative or scientific sizes"
fi
SC_DOCKER_IMAGES_RECLAIM="6.172e+08B"
[ "$(sc_action_estimate docker-unused-images)" = "617.20 MB" ] || fail "positive scientific estimate is normalized"
pass "Docker reclaimable size normalization"

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
sc_is_executable_action time-machine-thin || fail "Time Machine thinning action is registered"
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
[ "$(sc_action_risk time-machine-thin)" = "HIGH" ] || fail "snapshot thinning risk is HIGH"
[ "$(sc_action_option time-machine-thin)" = "Custom only" ] || fail "snapshot thinning is Custom only"
[ "$(sc_action_option ai-assistant-caches)" = "Manual review" ] || fail "AI caches are manual review"
pass "read-only reason matrix policy"

SC_DISK_TOTAL_BYTES=536870912000
sc_configure_tm_thin_request 40 4 || fail "valid Time Machine thinning request"
[ "${SC_TM_THIN_GIB}" = "40" ] || fail "Time Machine GiB target"
[ "${SC_TM_THIN_BYTES}" = "42949672960" ] || fail "Time Machine GiB-to-bytes conversion"
[ "${SC_TM_THIN_URGENCY}" = "4" ] || fail "Time Machine urgency"
[ "$(sc_approval_phrase time-machine-thin CUSTOM)" = "THIN TIME MACHINE SNAPSHOTS 40 GIB" ] || fail "dedicated Time Machine approval phrase"
[ "$(sc_action_preview_command time-machine-thin)" = "tmutil thinlocalsnapshots / 42949672960 4" ] || fail "exact tmutil preview"
tm_plan="$(sc_show_plan time-machine-thin)"
printf '%s' "${tm_plan}" | grep -q 'tmutil thinlocalsnapshots / 42949672960 4' || fail "Time Machine plan shows exact command"
printf '%s' "${tm_plan}" | grep -q 'Approved reclaim request: up to 40 GiB' || fail "Time Machine plan shows approved target"
printf '%s' "${tm_plan}" | grep -q 'APFS update snapshots remain excluded' || fail "Time Machine plan preserves APFS update snapshots"
if sc_configure_tm_thin_request 0 4 2>/dev/null; then
  fail "zero GiB target must be rejected"
fi
if sc_configure_tm_thin_request 1.5 4 2>/dev/null; then
  fail "fractional GiB target must be rejected"
fi
if sc_configure_tm_thin_request 40 5 2>/dev/null; then
  fail "urgency outside 1-4 must be rejected"
fi
if sc_configure_tm_thin_request 501 4 2>/dev/null; then
  fail "target larger than disk capacity must be rejected"
fi
SC_DISK_TOTAL_BYTES=0
if sc_configure_tm_thin_request 40 4 2>/dev/null; then
  fail "snapshot thinning requires audited disk capacity"
fi
SC_DISK_TOTAL_BYTES=536870912000
pass "Time Machine thinning parameter validation"

SC_TM_SNAPSHOT_COUNT=2
sc_configure_tm_thin_request 40 4 || fail "restore valid Time Machine request"
sc_validate_selected_policy time-machine-thin || fail "eligible Time Machine selection"
mixed_tm_selection="$(printf '%s\n' time-machine-thin dev-caches)"
if sc_validate_selected_policy "${mixed_tm_selection}" 2>/dev/null; then
  fail "Time Machine thinning must run alone"
fi
SC_TM_SNAPSHOT_COUNT=0
if sc_validate_selected_policy time-machine-thin 2>/dev/null; then
  fail "Time Machine thinning requires an audited snapshot"
fi
SC_TM_SNAPSHOT_COUNT=2
sc_custom_actions >/dev/null 2>&1 <<'EOF' || fail "Custom Time Machine configuration"
8
40
4
EOF
[ "${SC_SELECTED_ACTIONS}" = "time-machine-thin" ] || fail "Custom selection stores Time Machine action"
if sc_custom_actions >/dev/null 2>&1 <<'EOF'
1,8
EOF
then
  fail "Custom selection must reject mixed Time Machine actions"
fi
sc_custom_actions >/dev/null 2>&1 <<'EOF' || fail "ordinary Custom selection"
1,4
EOF
[ "${SC_SELECTED_ACTIONS}" = "$(printf '%s\n' docker-stopped-containers dev-caches)" ] || fail "ordinary Custom actions remain selectable"
pass "Time Machine Custom-only policy"

sc_ensure_temp
printf '%s\n' 'com.apple.TimeMachine.2026-08-22-133354.local' > "${SC_TM_SNAPSHOT_FILE}"
SC_TM_SNAPSHOT_COUNT=1
sc_configure_tm_thin_request 40 4 || fail "signature request configuration"
tm_signature_before="$(sc_target_signature time-machine-thin)"
printf '%s\n' 'com.apple.TimeMachine.2026-08-23-133836.local' >> "${SC_TM_SNAPSHOT_FILE}"
SC_TM_SNAPSHOT_COUNT=2
tm_signature_after="$(sc_target_signature time-machine-thin)"
[ "${tm_signature_before}" != "${tm_signature_after}" ] || fail "snapshot inventory change must alter target signature"
pass "Time Machine target signature"

tmutil_mock_log="${SC_TEMP_DIR}/tmutil-mock.log"
tmutil_exec_log="${SC_TEMP_DIR}/tmutil-exec.log"
(
  sc_have() {
    [ "$1" = "tmutil" ]
  }
  tmutil() {
    printf '%s\n' "$*" >> "${tmutil_mock_log}"
    case "$1" in
      listlocalsnapshots)
        printf '%s\n' 'Snapshots for disk /:' 'com.apple.TimeMachine.2026-08-22-133354.local'
        ;;
      thinlocalsnapshots)
        printf '%s\n' 'mock thinning complete'
        ;;
      *) return 1 ;;
    esac
  }
  SC_EXEC_LOG="${tmutil_exec_log}"
  SC_TM_THIN_GIB=40
  SC_TM_THIN_BYTES=42949672960
  SC_TM_THIN_URGENCY=4
  sc_execute_time_machine_thin >/dev/null
) || fail "mocked Time Machine execution"
[ "$(grep -c '^listlocalsnapshots /$' "${tmutil_mock_log}")" -eq 2 ] || fail "before and after snapshot inventories"
grep -q '^thinlocalsnapshots / 42949672960 4$' "${tmutil_mock_log}" || fail "mock received exact tmutil thinning command"
if grep -q 'sudo\|rm ' "${tmutil_mock_log}"; then
  fail "Time Machine execution must not invoke sudo or rm"
fi
grep -q '^+ tmutil listlocalsnapshots /$' "${tmutil_exec_log}" || fail "execution log records snapshot inventory commands"
grep -q '^+ tmutil thinlocalsnapshots / 42949672960 4$' "${tmutil_exec_log}" || fail "execution log records exact thinning command"
pass "mocked Time Machine execution"

help_output="$(SC_SKIP_MAIN=0 /bin/bash "${SCRIPT_PATH}" help)" || fail "help command"
printf '%s' "${help_output}" | grep -q 'audit' || fail "help mentions audit"
printf '%s' "${help_output}" | grep -Fq 'run [A|B]' || fail "help documents protected app handoff"
printf '%s' "${help_output}" | grep -Fq 'app-run [A|B]' || fail "help documents native app cleanup session"
printf '%s' "${help_output}" | grep -q 'exact typed approval phrase' || fail "help documents approval gate"
pass "help output"

ui_approved_output="$({
  SC_APP_PROTOCOL=1
  SC_APP_SESSION=1
  SC_USER_HOME="${SC_TEMP_DIR}"
  SC_DISK_FREE_BYTES=1024
  sc_collect_facts() { SC_DISK_FREE_BYTES=1024; }
  sc_print_audit_summary() { :; }
  sc_print_reason_matrix() { :; }
  sc_validate_selected_policy() { :; }
  sc_show_plan() { printf 'MOCK_PLAN:%s\n' "$1"; }
  sc_target_signature() { printf 'stable-test-signature'; }
  sc_collect_simulator() { :; }
  sc_run_phase() { shift; "$@"; }
  sc_execute_selected() { printf 'MOCK_EXECUTE:%s\n' "$1"; }
  sc_collect_disk() { SC_DISK_FREE_BYTES=2048; }
  printf '%s\n' 'DELETE PACKAGE-A' | sc_run_interactive A 2>&1
})" || fail "approved native app session"
printf '%s\n' "${ui_approved_output}" | grep -Fq '@@STORAGE_CLEARER:approval:DELETE PACKAGE-A@@' || fail "native app receives exact approval phrase"
printf '%s\n' "${ui_approved_output}" | grep -Fq '@@STORAGE_CLEARER:execution-started:PACKAGE-A@@' || fail "native app receives execution boundary"
printf '%s\n' "${ui_approved_output}" | grep -Fq 'MOCK_EXECUTE:' || fail "matching native approval reaches mocked execution"

ui_rejected_output="$({
  SC_APP_PROTOCOL=1
  SC_APP_SESSION=1
  SC_USER_HOME="${SC_TEMP_DIR}"
  sc_collect_facts() { SC_DISK_FREE_BYTES=1024; }
  sc_print_audit_summary() { :; }
  sc_print_reason_matrix() { :; }
  sc_validate_selected_policy() { :; }
  sc_show_plan() { :; }
  sc_target_signature() { printf 'stable-test-signature'; }
  sc_execute_selected() { printf 'MOCK_EXECUTE:%s\n' "$1"; }
  printf '%s\n' 'WRONG PHRASE' | sc_run_interactive A 2>&1
})" || fail "rejected native app session"
printf '%s\n' "${ui_rejected_output}" | grep -Fq '@@STORAGE_CLEARER:cancelled:approval-mismatch@@' || fail "native app receives approval mismatch"
if printf '%s\n' "${ui_rejected_output}" | grep -Fq 'MOCK_EXECUTE:'; then
  fail "mismatched native approval must not execute"
fi
pass "native app protected cleanup protocol"

spinner_output="$(SC_NO_ANIMATION=1 sc_spinner_start 'test phase' 2>&1; SC_NO_ANIMATION=1 sc_spinner_stop done 2>&1)"
printf '%s' "${spinner_output}" | grep -q '\[done\] test phase' || fail "static spinner fallback"
pass "spinner fallback"

printf 'All tests passed. No cleanup commands were executed.\n'
