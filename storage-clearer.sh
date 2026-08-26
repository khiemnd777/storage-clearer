#!/bin/bash

# macOS Storage Clearer
# Safe-by-default storage triage and explicitly approved cleanup.
# Compatible with the Bash 3.2 shipped with macOS.

set -u
set -o pipefail

SC_VERSION="1.3.0"
SC_USER_HOME="${HOME:?HOME is not set}"
SC_DATA_MOUNT="/"
SC_TEMP_DIR=""
SC_RUNTIME_FILE=""
SC_OLD_RUNTIME_FILE=""
SC_TM_SNAPSHOT_FILE=""
SC_EXEC_LOG=""
SC_SPINNER_PID=""
SC_SPINNER_MESSAGE=""
SC_SPINNER_STATIC=0
SC_SPINNER_STARTED_SECONDS=0
SC_SELECTED_ACTIONS=""
SC_TM_THIN_GIB=""
SC_TM_THIN_BYTES=0
SC_TM_THIN_URGENCY=""

SC_DISK_TOTAL_BYTES=0
SC_DISK_USED_BYTES=0
SC_DISK_FREE_BYTES=0
SC_DATA_DEVICE="unknown"
SC_TM_SNAPSHOT_COUNT="unknown"
SC_APFS_DATA_SNAPSHOT_COUNT="unknown"

SC_DOCKER_READY=0
SC_DOCKER_RAW_PATH="${SC_USER_HOME}/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
SC_DOCKER_RAW_BYTES=0
SC_DOCKER_IMAGES_TOTAL="unknown"
SC_DOCKER_IMAGES_RECLAIM="unknown"
SC_DOCKER_CONTAINERS_TOTAL="unknown"
SC_DOCKER_CONTAINERS_RECLAIM="unknown"
SC_DOCKER_VOLUMES_TOTAL="unknown"
SC_DOCKER_VOLUMES_RECLAIM="unknown"
SC_DOCKER_BUILD_TOTAL="unknown"
SC_DOCKER_BUILD_RECLAIM="unknown"

SC_DEV_CACHE_BYTES=0
SC_SIM_LATEST_VERSION="unknown"
SC_SIM_OLD_COUNT=0
SC_SIM_OLD_BYTES=0
SC_SIM_UNAVAILABLE_COUNT=0
SC_SIM_UNAVAILABLE_BYTES=0
SC_WORKS_BYTES=0
SC_WORKS_GENERATED_BYTES=0
SC_CODEX_SESSION_BYTES=0
SC_AI_CACHE_BYTES=0
SC_BROWSER_REVIEW_BYTES=0

SC_GO_MODULE_CACHE="${SC_USER_HOME}/go/pkg/mod"
SC_GO_BUILD_CACHE="${SC_USER_HOME}/Library/Caches/go-build"

SC_DEV_CACHE_TARGETS=(
  "${SC_USER_HOME}/.npm/_cacache"
  "${SC_USER_HOME}/.npm/_npx"
  "${SC_USER_HOME}/.bun/install/cache"
  "${SC_USER_HOME}/.gradle/caches"
  "${SC_GO_MODULE_CACHE}"
  "${SC_GO_BUILD_CACHE}"
  "${SC_USER_HOME}/.pub-cache"
  "${SC_USER_HOME}/Library/pnpm"
  "${SC_USER_HOME}/Library/Caches/pnpm"
  "${SC_USER_HOME}/Library/Caches/pip"
  "${SC_USER_HOME}/Library/Caches/node-gyp"
  "${SC_USER_HOME}/Library/Caches/ms-playwright"
  "${SC_USER_HOME}/Library/Caches/ms-playwright-go"
  "${SC_USER_HOME}/Library/Caches/Homebrew"
  "${SC_USER_HOME}/Library/Caches/CocoaPods"
  "${SC_USER_HOME}/Library/Caches/Yarn"
)

# These application-specific locations are measured for review only. They are
# deliberately absent from both cleanup packages and the executable allowlist.
SC_AI_CACHE_TARGETS=(
  "${SC_USER_HOME}/Library/Application Support/Claude/vm_bundles"
  "${SC_USER_HOME}/Library/Application Support/Claude/Cache"
  "${SC_USER_HOME}/Library/Application Support/Claude/Code Cache"
  "${SC_USER_HOME}/Library/Application Support/Claude/GPUCache"
  "${SC_USER_HOME}/Library/Application Support/Claude/DawnWebGPUCache"
  "${SC_USER_HOME}/Library/Application Support/Claude/DawnGraphiteCache"
  "${SC_USER_HOME}/Library/Caches/Codex"
)

# Only these paths may be passed to rm. Go caches are intentionally read-only
# and must be cleaned through `go clean`, not by changing permissions or using rm.
SC_DIRECT_CACHE_TARGETS=(
  "${SC_USER_HOME}/.npm/_cacache"
  "${SC_USER_HOME}/.npm/_npx"
  "${SC_USER_HOME}/.bun/install/cache"
  "${SC_USER_HOME}/.gradle/caches"
  "${SC_USER_HOME}/.pub-cache"
  "${SC_USER_HOME}/Library/pnpm"
  "${SC_USER_HOME}/Library/Caches/pnpm"
  "${SC_USER_HOME}/Library/Caches/pip"
  "${SC_USER_HOME}/Library/Caches/node-gyp"
  "${SC_USER_HOME}/Library/Caches/ms-playwright"
  "${SC_USER_HOME}/Library/Caches/ms-playwright-go"
  "${SC_USER_HOME}/Library/Caches/Homebrew"
  "${SC_USER_HOME}/Library/Caches/CocoaPods"
  "${SC_USER_HOME}/Library/Caches/Yarn"
)

SC_EXECUTABLE_ACTIONS=(
  "docker-stopped-containers"
  "docker-unused-images"
  "docker-build-cache"
  "dev-caches"
  "simulator-old-runtimes"
  "simulator-unavailable-devices"
  "docker-unused-volumes"
  "time-machine-thin"
)

SC_MATRIX_ACTIONS=(
  "time-machine-snapshots"
  "time-machine-thin"
  "docker-build-cache"
  "docker-unused-images"
  "docker-stopped-containers"
  "docker-unused-volumes"
  "dev-caches"
  "simulator-old-runtimes"
  "simulator-unavailable-devices"
  "browser-site-data"
  "works-generated"
  "ai-assistant-caches"
  "codex-sessions"
)

sc_cleanup_temp() {
  if [ -n "${SC_TEMP_DIR}" ] && [ -d "${SC_TEMP_DIR}" ]; then
    case "${SC_TEMP_DIR}" in
      /tmp/storage-clearer.*|/private/tmp/storage-clearer.*)
        /bin/rm -rf "${SC_TEMP_DIR}"
        ;;
    esac
  fi
}

sc_spinner_supported() {
  [ "${SC_NO_ANIMATION:-0}" != "1" ] && [ -t 2 ] && [ "${TERM:-dumb}" != "dumb" ]
}

sc_spinner_start() {
  local message="$1"
  SC_SPINNER_MESSAGE="${message}"
  SC_SPINNER_STATIC=0
  SC_SPINNER_STARTED_SECONDS=${SECONDS}

  if ! sc_spinner_supported; then
    printf '  [....] %s\n' "${message}" >&2
    SC_SPINNER_STATIC=1
    return 0
  fi

  (
    local frames='|/-\\'
    local index=0
    local frame
    local started=${SECONDS}
    local elapsed=0
    while :; do
      frame="${frames:${index}:1}"
      elapsed=$((SECONDS - started))
      printf '\r\033[2K  [%s] %s (%ss)' "${frame}" "${message}" "${elapsed}" >&2
      index=$(((index + 1) % 4))
      sleep 0.12
    done
  ) &
  SC_SPINNER_PID=$!
}

sc_spinner_cancel() {
  if [ -n "${SC_SPINNER_PID}" ]; then
    kill "${SC_SPINNER_PID}" 2>/dev/null || true
    wait "${SC_SPINNER_PID}" 2>/dev/null || true
    SC_SPINNER_PID=""
    if sc_spinner_supported; then
      printf '\r\033[2K' >&2
    fi
  fi
}

sc_spinner_stop() {
  local status="${1:-done}"
  local marker='done'
  local elapsed=$((SECONDS - SC_SPINNER_STARTED_SECONDS))
  [ "${status}" = "done" ] || marker='fail'

  sc_spinner_cancel
  printf '  [%s] %s (%ss)\n' "${marker}" "${SC_SPINNER_MESSAGE}" "${elapsed}" >&2
  SC_SPINNER_MESSAGE=""
  SC_SPINNER_STATIC=0
}

sc_run_phase() {
  local message="$1"
  local status
  shift
  sc_spinner_start "${message}"
  "$@"
  status=$?
  if [ "${status}" -eq 0 ]; then
    sc_spinner_stop done
  else
    sc_spinner_stop fail
  fi
  return "${status}"
}

sc_on_exit() {
  sc_spinner_cancel
  sc_cleanup_temp
}

trap sc_on_exit EXIT

sc_have() {
  command -v "$1" >/dev/null 2>&1
}

sc_info() {
  printf '%s\n' "$*"
}

sc_warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

sc_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

sc_ensure_temp() {
  if [ -z "${SC_TEMP_DIR}" ]; then
    SC_TEMP_DIR="$(mktemp -d /tmp/storage-clearer.XXXXXX)" || sc_die "Cannot create temporary directory"
    SC_RUNTIME_FILE="${SC_TEMP_DIR}/runtimes.tsv"
    SC_OLD_RUNTIME_FILE="${SC_TEMP_DIR}/old-runtimes.tsv"
    SC_TM_SNAPSHOT_FILE="${SC_TEMP_DIR}/time-machine-snapshots.txt"
  fi
}

sc_human_bytes() {
  awk -v bytes="${1:-0}" 'BEGIN {
    split("B KB MB GB TB", units, " ")
    value = bytes + 0
    unit = 1
    while (value >= 1000 && unit < 5) {
      value = value / 1000
      unit++
    }
    if (unit == 1) printf "%.0f %s", value, units[unit]
    else printf "%.2f %s", value, units[unit]
  }'
}

sc_size_to_bytes() {
  awk -v raw="${1:-0}" 'BEGIN {
    value = raw
    gsub(/[[:space:]]/, "", value)
    number = value + 0
    unit = value
    sub(/^[0-9.]+/, "", unit)
    multiplier = 1
    if (unit == "KB" || unit == "K" || unit == "kB" || unit == "k") multiplier = 1000
    else if (unit == "MB" || unit == "M") multiplier = 1000000
    else if (unit == "GB" || unit == "G") multiplier = 1000000000
    else if (unit == "TB" || unit == "T") multiplier = 1000000000000
    printf "%.0f", number * multiplier
  }'
}

sc_du_bytes() {
  local target="${1:-}"
  if [ -z "${target}" ] || [ ! -e "${target}" ]; then
    printf '0\n'
    return 0
  fi
  /usr/bin/du -sk "${target}" 2>/dev/null | awk '
    NR == 1 {printf "%.0f\n", $1 * 1024; found = 1}
    END {if (!found) print "0"}
  '
}

sc_sum_paths_bytes() {
  local total=0
  local target
  local value
  for target in "$@"; do
    value="$(sc_du_bytes "${target}")"
    total=$((total + value))
  done
  printf '%s\n' "${total}"
}

sc_trim_reclaim() {
  printf '%s' "${1:-unknown}" | sed 's/[[:space:]]*(.*)$//'
}

sc_parse_tm_snapshot_output() {
  awk '/^com\.apple\.TimeMachine\.[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]\.local$/ {print}'
}

sc_tm_snapshot_timestamp() {
  local name="${1:-}"
  local stamp
  stamp="${name#com.apple.TimeMachine.}"
  stamp="${stamp%.local}"
  case "${stamp}" in
    ????-??-??-??????)
      printf '%s %s:%s:%s' \
        "${stamp:0:10}" "${stamp:11:2}" "${stamp:13:2}" "${stamp:15:2}"
      ;;
    *)
      printf 'date unavailable'
      ;;
  esac
}

sc_collect_disk() {
  local disk_line
  local tm_snapshot_output
  local snapshot_output

  if [ -d "/System/Volumes/Data" ]; then
    SC_DATA_MOUNT="/System/Volumes/Data"
  fi

  disk_line="$(df -k "${SC_DATA_MOUNT}" 2>/dev/null | awk 'NR == 2 {printf "%.0f|%.0f|%.0f|%s", $2 * 1024, $3 * 1024, $4 * 1024, $1}')"
  if [ -n "${disk_line}" ]; then
    SC_DISK_TOTAL_BYTES="$(printf '%s' "${disk_line}" | awk -F '|' '{print $1}')"
    SC_DISK_USED_BYTES="$(printf '%s' "${disk_line}" | awk -F '|' '{print $2}')"
    SC_DISK_FREE_BYTES="$(printf '%s' "${disk_line}" | awk -F '|' '{print $3}')"
    SC_DATA_DEVICE="$(printf '%s' "${disk_line}" | awk -F '|' '{print $4}' | sed 's#^/dev/##')"
  fi

  sc_ensure_temp
  : > "${SC_TM_SNAPSHOT_FILE}"
  SC_TM_SNAPSHOT_COUNT="unknown"
  SC_APFS_DATA_SNAPSHOT_COUNT="unknown"
  if sc_have tmutil && tm_snapshot_output="$(tmutil listlocalsnapshots / 2>/dev/null)"; then
    printf '%s\n' "${tm_snapshot_output}" | sc_parse_tm_snapshot_output > "${SC_TM_SNAPSHOT_FILE}"
    SC_TM_SNAPSHOT_COUNT="$(awk 'NF {count++} END {print count + 0}' "${SC_TM_SNAPSHOT_FILE}")"
  fi

  if sc_have diskutil && [ "${SC_DATA_DEVICE}" != "unknown" ]; then
    snapshot_output="$(diskutil apfs listSnapshots "${SC_DATA_DEVICE}" 2>/dev/null || true)"
    if printf '%s' "${snapshot_output}" | grep -q 'No snapshots'; then
      SC_APFS_DATA_SNAPSHOT_COUNT=0
    elif [ -n "${snapshot_output}" ]; then
      SC_APFS_DATA_SNAPSHOT_COUNT="$(printf '%s\n' "${snapshot_output}" | awk '/Snapshot UUID:/ {count++} END {print count + 0}')"
    fi
  fi
}

sc_collect_docker() {
  local docker_table
  local kind total_count active_count size reclaim

  SC_DOCKER_RAW_BYTES="$(sc_du_bytes "${SC_DOCKER_RAW_PATH}")"
  if ! sc_have docker; then
    return 0
  fi

  docker_table="$(docker system df --format '{{.Type}}|{{.TotalCount}}|{{.Active}}|{{.Size}}|{{.Reclaimable}}' 2>/dev/null || true)"
  if [ -z "${docker_table}" ]; then
    return 0
  fi

  SC_DOCKER_READY=1
  sc_ensure_temp
  printf '%s\n' "${docker_table}" > "${SC_TEMP_DIR}/docker-df.tsv"
  while IFS='|' read -r kind total_count active_count size reclaim; do
    reclaim="$(sc_trim_reclaim "${reclaim}")"
    case "${kind}" in
      Images)
        SC_DOCKER_IMAGES_TOTAL="${size}"
        SC_DOCKER_IMAGES_RECLAIM="${reclaim}"
        ;;
      Containers)
        SC_DOCKER_CONTAINERS_TOTAL="${size}"
        SC_DOCKER_CONTAINERS_RECLAIM="${reclaim}"
        ;;
      "Local Volumes")
        SC_DOCKER_VOLUMES_TOTAL="${size}"
        SC_DOCKER_VOLUMES_RECLAIM="${reclaim}"
        ;;
      "Build Cache")
        SC_DOCKER_BUILD_TOTAL="${size}"
        SC_DOCKER_BUILD_RECLAIM="${reclaim}"
        ;;
    esac
  done < "${SC_TEMP_DIR}/docker-df.tsv"
}

sc_version_key() {
  awk -v version="${1:-0}" 'BEGIN {
    split(version, parts, ".")
    printf "%05d%05d%05d", parts[1] + 0, parts[2] + 0, parts[3] + 0
  }'
}

sc_runtime_device_key() {
  awk -v version="${1:-0}" 'BEGIN {
    split(version, parts, ".")
    printf "com.apple.CoreSimulator.SimRuntime.iOS-%d-%d", parts[1] + 0, parts[2] + 0
  }'
}

sc_sim_asset_bytes_for_build() {
  local requested_build="$1"
  local base="/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime"
  local plist build asset_dir

  if [ ! -d "${base}" ] || ! sc_have plutil; then
    printf '0\n'
    return 0
  fi

  for plist in "${base}"/*.asset/Info.plist; do
    [ -f "${plist}" ] || continue
    build="$(plutil -extract MobileAssetProperties.Build raw "${plist}" 2>/dev/null || true)"
    if [ "${build}" = "${requested_build}" ]; then
      asset_dir="$(dirname "${plist}")"
      sc_du_bytes "${asset_dir}"
      return 0
    fi
  done
  printf '0\n'
}

sc_sim_dyld_bytes_for_build() {
  local requested_build="$1"
  local base="/Library/Developer/CoreSimulator/Caches/dyld"
  local total=0 path value

  if [ ! -d "${base}" ]; then
    printf '0\n'
    return 0
  fi

  sc_ensure_temp
  find "${base}" -type d -name "*.${requested_build}" -print 2>/dev/null > "${SC_TEMP_DIR}/dyld-${requested_build}.txt"
  while IFS= read -r path; do
    [ -n "${path}" ] || continue
    value="$(sc_du_bytes "${path}")"
    total=$((total + value))
  done < "${SC_TEMP_DIR}/dyld-${requested_build}.txt"
  printf '%s\n' "${total}"
}

sc_sim_device_bytes_for_version() {
  local version="$1"
  local expected_runtime
  local base="${SC_USER_HOME}/Library/Developer/CoreSimulator/Devices"
  local plist runtime device_dir value total=0

  expected_runtime="$(sc_runtime_device_key "${version}")"
  if [ ! -d "${base}" ] || ! sc_have plutil; then
    printf '0\n'
    return 0
  fi

  for plist in "${base}"/*/device.plist; do
    [ -f "${plist}" ] || continue
    runtime="$(plutil -extract runtime raw "${plist}" 2>/dev/null || true)"
    if [ "${runtime}" = "${expected_runtime}" ]; then
      device_dir="$(dirname "${plist}")"
      value="$(sc_du_bytes "${device_dir}")"
      total=$((total + value))
    fi
  done
  printf '%s\n' "${total}"
}

sc_collect_simulator() {
  local runtime_output latest_line version build uuid reported
  local old_asset old_dyld old_devices
  local device_output device_uuid value

  sc_ensure_temp
  : > "${SC_RUNTIME_FILE}"
  : > "${SC_OLD_RUNTIME_FILE}"
  SC_SIM_LATEST_VERSION="unknown"
  SC_SIM_OLD_COUNT=0
  SC_SIM_OLD_BYTES=0
  SC_SIM_UNAVAILABLE_COUNT=0
  SC_SIM_UNAVAILABLE_BYTES=0

  if ! sc_have xcrun; then
    return 0
  fi

  runtime_output="$(xcrun simctl runtime list -v 2>/dev/null || true)"
  if [ -n "${runtime_output}" ]; then
    printf '%s\n' "${runtime_output}" | awk '
      /^iOS [0-9]/ {
        version = $2
        build = $3
        gsub(/[()]/, "", build)
        uuid = $5
        next
      }
      /^[[:space:]]+Size:/ && uuid != "" {
        print version "|" build "|" uuid "|" $2
        uuid = ""
      }
    ' > "${SC_RUNTIME_FILE}"
  fi

  if [ -s "${SC_RUNTIME_FILE}" ]; then
    latest_line="$(while IFS='|' read -r version build uuid reported; do printf '%s|%s\n' "$(sc_version_key "${version}")" "${version}"; done < "${SC_RUNTIME_FILE}" | sort | tail -1)"
    SC_SIM_LATEST_VERSION="$(printf '%s' "${latest_line}" | awk -F '|' '{print $2}')"
    awk -F '|' -v latest="${SC_SIM_LATEST_VERSION}" '$1 != latest {print}' "${SC_RUNTIME_FILE}" > "${SC_OLD_RUNTIME_FILE}"
    SC_SIM_OLD_COUNT="$(awk 'END {print NR + 0}' "${SC_OLD_RUNTIME_FILE}")"

    while IFS='|' read -r version build uuid reported; do
      [ -n "${version}" ] || continue
      old_asset="$(sc_sim_asset_bytes_for_build "${build}")"
      old_dyld="$(sc_sim_dyld_bytes_for_build "${build}")"
      old_devices="$(sc_sim_device_bytes_for_version "${version}")"
      SC_SIM_OLD_BYTES=$((SC_SIM_OLD_BYTES + old_asset + old_dyld + old_devices))
    done < "${SC_OLD_RUNTIME_FILE}"
  fi

  device_output="$(xcrun simctl list devices 2>/dev/null || true)"
  if [ -n "${device_output}" ]; then
    printf '%s\n' "${device_output}" | awk '/unavailable/ {
      if (match($0, /[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/))
        print substr($0, RSTART, RLENGTH)
    }' > "${SC_TEMP_DIR}/unavailable-devices.txt"

    while IFS= read -r device_uuid; do
      [ -n "${device_uuid}" ] || continue
      SC_SIM_UNAVAILABLE_COUNT=$((SC_SIM_UNAVAILABLE_COUNT + 1))
      value="$(sc_du_bytes "${SC_USER_HOME}/Library/Developer/CoreSimulator/Devices/${device_uuid}")"
      SC_SIM_UNAVAILABLE_BYTES=$((SC_SIM_UNAVAILABLE_BYTES + value))
    done < "${SC_TEMP_DIR}/unavailable-devices.txt"
  fi
}

sc_collect_secondary() {
  local generated_kib

  SC_DEV_CACHE_BYTES="$(sc_sum_paths_bytes "${SC_DEV_CACHE_TARGETS[@]}")"
  SC_WORKS_BYTES="$(sc_du_bytes "${SC_USER_HOME}/Works")"
  SC_CODEX_SESSION_BYTES="$(sc_du_bytes "${SC_USER_HOME}/.codex/sessions")"
  SC_AI_CACHE_BYTES="$(sc_sum_paths_bytes "${SC_AI_CACHE_TARGETS[@]}")"

  generated_kib=0
  if [ -d "${SC_USER_HOME}/Works" ]; then
    generated_kib="$(find "${SC_USER_HOME}/Works" -type d \( -name node_modules -o -name .next -o -name dist -o -name build -o -name target -o -name coverage \) -prune -exec /usr/bin/du -sk {} + 2>/dev/null | awk '{sum += $1} END {printf "%.0f", sum + 0}')"
  fi
  SC_WORKS_GENERATED_BYTES=$((generated_kib * 1024))

  SC_BROWSER_REVIEW_BYTES="$(sc_sum_paths_bytes \
    "${SC_USER_HOME}/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel" \
    "${SC_USER_HOME}/Library/Application Support/Google/GoogleUpdater/crx_cache" \
    "${SC_USER_HOME}/Library/Application Support/Microsoft Edge/Default/Service Worker/CacheStorage" \
    "${SC_USER_HOME}/Library/Application Support/Microsoft Edge/Default/IndexedDB/https_www.messenger.com_0.indexeddb.blob")"
}

sc_collect_facts() {
  sc_info "Collecting read-only storage facts..."
  sc_run_phase "Disk usage and APFS snapshots" sc_collect_disk
  sc_run_phase "Docker storage and reclaimable objects" sc_collect_docker
  sc_run_phase "iOS Simulator runtimes, caches, and devices" sc_collect_simulator
  sc_run_phase "Developer, browser, project, and AI cache inventory" sc_collect_secondary
}

sc_action_label() {
  case "$1" in
    time-machine-snapshots) printf 'Time Machine/APFS snapshots' ;;
    time-machine-thin) printf 'Time Machine snapshot thinning' ;;
    docker-stopped-containers) printf 'Docker stopped containers' ;;
    docker-unused-images) printf 'Docker unused images' ;;
    docker-build-cache) printf 'Docker build cache' ;;
    docker-unused-volumes) printf 'Docker unused volumes' ;;
    dev-caches) printf 'Developer caches' ;;
    simulator-old-runtimes) printf 'Old iOS runtimes' ;;
    simulator-unavailable-devices) printf 'Unavailable simulators' ;;
    browser-site-data) printf 'Browser models/site data' ;;
    works-generated) printf 'Generated project folders' ;;
    ai-assistant-caches) printf 'AI assistant caches' ;;
    codex-sessions) printf 'Codex session history' ;;
    *) printf '%s' "$1" ;;
  esac
}

sc_action_risk() {
  case "$1" in
    docker-build-cache|docker-unused-images|docker-stopped-containers|dev-caches|simulator-unavailable-devices) printf 'LOW' ;;
    simulator-old-runtimes|browser-site-data|works-generated) printf 'MEDIUM' ;;
    docker-unused-volumes|time-machine-snapshots|time-machine-thin|codex-sessions) printf 'HIGH' ;;
    ai-assistant-caches) printf 'MEDIUM' ;;
    *) printf 'UNKNOWN' ;;
  esac
}

sc_action_option() {
  case "$1" in
    docker-build-cache|docker-unused-images|docker-stopped-containers|dev-caches|simulator-unavailable-devices) printf 'A/B/Custom' ;;
    simulator-old-runtimes) printf 'B/Custom' ;;
    docker-unused-volumes|time-machine-thin) printf 'Custom only' ;;
    browser-site-data|works-generated|time-machine-snapshots|ai-assistant-caches|codex-sessions) printf 'Manual review' ;;
    *) printf '-' ;;
  esac
}

sc_action_estimate() {
  case "$1" in
    time-machine-snapshots) printf 'unknown' ;;
    time-machine-thin)
      if [ -n "${SC_TM_THIN_GIB}" ]; then
        printf 'up to %s GiB' "${SC_TM_THIN_GIB}"
      else
        printf 'user-defined'
      fi
      ;;
    docker-build-cache) printf '%s' "${SC_DOCKER_BUILD_RECLAIM}" ;;
    docker-unused-images) printf '%s' "${SC_DOCKER_IMAGES_RECLAIM}" ;;
    docker-stopped-containers) printf '%s' "${SC_DOCKER_CONTAINERS_RECLAIM}" ;;
    docker-unused-volumes) printf '%s' "${SC_DOCKER_VOLUMES_RECLAIM}" ;;
    dev-caches) sc_human_bytes "${SC_DEV_CACHE_BYTES}" ;;
    simulator-old-runtimes) sc_human_bytes "${SC_SIM_OLD_BYTES}" ;;
    simulator-unavailable-devices) sc_human_bytes "${SC_SIM_UNAVAILABLE_BYTES}" ;;
    browser-site-data) sc_human_bytes "${SC_BROWSER_REVIEW_BYTES}" ;;
    works-generated) sc_human_bytes "${SC_WORKS_GENERATED_BYTES}" ;;
    ai-assistant-caches) sc_human_bytes "${SC_AI_CACHE_BYTES}" ;;
    codex-sessions) sc_human_bytes "${SC_CODEX_SESSION_BYTES}" ;;
    *) printf 'unknown' ;;
  esac
}

sc_action_estimate_bytes() {
  case "$1" in
    time-machine-snapshots) printf '0' ;;
    time-machine-thin) printf '0' ;;
    docker-build-cache) sc_size_to_bytes "${SC_DOCKER_BUILD_RECLAIM}" ;;
    docker-unused-images) sc_size_to_bytes "${SC_DOCKER_IMAGES_RECLAIM}" ;;
    docker-stopped-containers) sc_size_to_bytes "${SC_DOCKER_CONTAINERS_RECLAIM}" ;;
    docker-unused-volumes) sc_size_to_bytes "${SC_DOCKER_VOLUMES_RECLAIM}" ;;
    dev-caches) printf '%s' "${SC_DEV_CACHE_BYTES}" ;;
    simulator-old-runtimes) printf '%s' "${SC_SIM_OLD_BYTES}" ;;
    simulator-unavailable-devices) printf '%s' "${SC_SIM_UNAVAILABLE_BYTES}" ;;
    browser-site-data) printf '%s' "${SC_BROWSER_REVIEW_BYTES}" ;;
    works-generated) printf '%s' "${SC_WORKS_GENERATED_BYTES}" ;;
    ai-assistant-caches) printf '%s' "${SC_AI_CACHE_BYTES}" ;;
    codex-sessions) printf '%s' "${SC_CODEX_SESSION_BYTES}" ;;
    *) printf '0' ;;
  esac
}

sc_action_reason_short() {
  case "$1" in
    time-machine-snapshots) printf 'Point-in-time copies can retain blocks after files are deleted' ;;
    time-machine-thin) printf 'macOS may reclaim local snapshot blocks up to a user-approved target' ;;
    docker-build-cache) printf 'Rebuildable layers; no active cache ownership' ;;
    docker-unused-images) printf 'Not referenced by any container' ;;
    docker-stopped-containers) printf 'Stopped writable layers only' ;;
    docker-unused-volumes) printf 'No container reference, but may contain orphan DB data' ;;
    dev-caches) printf 'Package/tool caches can be downloaded or rebuilt' ;;
    simulator-old-runtimes) printf 'Keep newest iOS; remove older runtime/cache/device sets' ;;
    simulator-unavailable-devices) printf 'Runtime is already missing' ;;
    browser-site-data) printf 'Mostly downloadable models/offline web data' ;;
    works-generated) printf 'node_modules/build outputs are reproducible' ;;
    ai-assistant-caches) printf 'App caches and VM bundles may be rebuildable but need app context' ;;
    codex-sessions) printf 'Large history, but deletion loses task records' ;;
    *) printf '-' ;;
  esac
}

sc_print_audit_summary() {
  sc_info ""
  sc_info "Storage triage"
  sc_info "  Data device:        ${SC_DATA_DEVICE}"
  sc_info "  Used:               $(sc_human_bytes "${SC_DISK_USED_BYTES}") / $(sc_human_bytes "${SC_DISK_TOTAL_BYTES}")"
  sc_info "  Free:               $(sc_human_bytes "${SC_DISK_FREE_BYTES}")"
  sc_info "  Time Machine snaps: ${SC_TM_SNAPSHOT_COUNT}"
  sc_info "  Data APFS snaps:    ${SC_APFS_DATA_SNAPSHOT_COUNT}"
  sc_info "  Docker.raw:         $(sc_human_bytes "${SC_DOCKER_RAW_BYTES}") allocated"
  sc_info "  Works:              $(sc_human_bytes "${SC_WORKS_BYTES}")"
  sc_info "  Latest iOS runtime: ${SC_SIM_LATEST_VERSION} (kept by Package B)"
  if [ "${SC_DOCKER_READY}" -ne 1 ]; then
    sc_warn "Docker daemon is unavailable; Docker reclaim estimates are incomplete."
  fi
}

sc_print_reason_matrix() {
  local action
  sc_info ""
  sc_info "Reason matrix"
  printf '%-32s | %-12s | %-8s | %-14s | %s\n' "CAUSE" "EST. RECLAIM" "RISK" "OPTION" "WHY"
  printf '%-32s-+-%-12s-+-%-8s-+-%-14s-+-%s\n' "--------------------------------" "------------" "--------" "--------------" "---------------------------------------------"
  for action in "${SC_MATRIX_ACTIONS[@]}"; do
    printf '%-32s | %-12s | %-8s | %-14s | %s\n' \
      "${action}" \
      "$(sc_action_estimate "${action}")" \
      "$(sc_action_risk "${action}")" \
      "$(sc_action_option "${action}")" \
      "$(sc_action_reason_short "${action}")"
  done
}

sc_print_tm_snapshot_evidence() {
  local snapshot_name
  sc_info "  Evidence: Time Machine snapshots: ${SC_TM_SNAPSHOT_COUNT}; Data-volume APFS snapshots: ${SC_APFS_DATA_SNAPSHOT_COUNT}."
  if [ -n "${SC_TM_SNAPSHOT_FILE}" ] && [ -s "${SC_TM_SNAPSHOT_FILE}" ]; then
    while IFS= read -r snapshot_name; do
      [ -n "${snapshot_name}" ] || continue
      sc_info "            $(sc_tm_snapshot_timestamp "${snapshot_name}") — ${snapshot_name}"
    done < "${SC_TM_SNAPSHOT_FILE}"
  elif [ "${SC_TM_SNAPSHOT_COUNT}" = "unknown" ]; then
    sc_info "            Snapshot names unavailable; tmutil may be missing or the terminal may need Full Disk Access."
  fi
}

sc_explain_action() {
  local action="$1"
  local target
  sc_info ""
  sc_info "[$(sc_action_risk "${action}")] ${action} — $(sc_action_label "${action}")"
  sc_info "  Estimate: $(sc_action_estimate "${action}")"
  sc_info "  Options:  $(sc_action_option "${action}")"
  case "${action}" in
    time-machine-snapshots)
      sc_print_tm_snapshot_evidence
      sc_info "  Effect: Report-only inventory. macOS normally removes local snapshots as they age or when space is needed."
      ;;
    time-machine-thin)
      sc_print_tm_snapshot_evidence
      if [ -n "${SC_TM_THIN_GIB}" ]; then
        sc_info "  Request: Reclaim up to ${SC_TM_THIN_GIB} GiB at urgency ${SC_TM_THIN_URGENCY}."
        sc_info "           $(sc_action_preview_command time-machine-thin)"
      else
        sc_info "  Request: GiB target and urgency are collected only after choosing this Custom action."
      fi
      sc_info "  Effect: HIGH risk. Local restore points may disappear. Uses tmutil only; never rm or automatic sudo."
      ;;
    docker-build-cache)
      sc_info "  Evidence: Docker build cache total ${SC_DOCKER_BUILD_TOTAL}; reclaimable ${SC_DOCKER_BUILD_RECLAIM}."
      sc_info "  Effect: Builds may be slower once because layers must be rebuilt."
      ;;
    docker-unused-images)
      sc_info "  Evidence: Images total ${SC_DOCKER_IMAGES_TOTAL}; reclaimable ${SC_DOCKER_IMAGES_RECLAIM}."
      sc_info "  Effect: Removed images must be pulled or rebuilt if needed later."
      ;;
    docker-stopped-containers)
      sc_info "  Evidence: Containers total ${SC_DOCKER_CONTAINERS_TOTAL}; reclaimable ${SC_DOCKER_CONTAINERS_RECLAIM}."
      sc_info "  Effect: Writable layers of stopped containers are lost; running containers are untouched."
      ;;
    docker-unused-volumes)
      sc_info "  Evidence: Volumes total ${SC_DOCKER_VOLUMES_TOTAL}; reclaimable ${SC_DOCKER_VOLUMES_RECLAIM}."
      sc_info "  Effect: Unreferenced databases/uploads can be permanently lost. Excluded from A and B."
      ;;
    dev-caches)
      sc_info "  Evidence: Allowlisted npm/Bun/Gradle/Go/Pub/pnpm/pip/node-gyp/Playwright caches total $(sc_human_bytes "${SC_DEV_CACHE_BYTES}")."
      sc_info "  Effect: Dependencies and browser binaries are re-downloaded; source files are untouched."
      ;;
    simulator-old-runtimes)
      sc_info "  Evidence: ${SC_SIM_OLD_COUNT} older runtime(s), keeping iOS ${SC_SIM_LATEST_VERSION}; estimate $(sc_human_bytes "${SC_SIM_OLD_BYTES}")."
      if [ -s "${SC_OLD_RUNTIME_FILE}" ]; then
        while IFS='|' read -r version build uuid reported; do
          sc_info "            iOS ${version} (${build}), ${reported}, id ${uuid}"
        done < "${SC_OLD_RUNTIME_FILE}"
      fi
      sc_info "  Effect: Those OS versions disappear from Simulator and must be downloaded again if needed."
      ;;
    simulator-unavailable-devices)
      sc_info "  Evidence: ${SC_SIM_UNAVAILABLE_COUNT} device(s) point to missing runtimes; $(sc_human_bytes "${SC_SIM_UNAVAILABLE_BYTES}")."
      sc_info "  Effect: Only unusable simulator device records/data are removed."
      ;;
    browser-site-data)
      sc_info "  Evidence: Downloaded Chrome models and selected Edge offline/site data total $(sc_human_bytes "${SC_BROWSER_REVIEW_BYTES}")."
      sc_info "  Effect: May sign out websites or remove offline data. Report-only; never auto-deleted."
      ;;
    works-generated)
      sc_info "  Evidence: Works totals $(sc_human_bytes "${SC_WORKS_BYTES}"); generated folders total $(sc_human_bytes "${SC_WORKS_GENERATED_BYTES}")."
      sc_info "  Effect: Builds/dependencies must be regenerated. Report-only because project context matters."
      ;;
    ai-assistant-caches)
      sc_info "  Evidence: Selected Claude Desktop VM/cache paths and the Codex application cache total $(sc_human_bytes "${SC_AI_CACHE_BYTES}")."
      for target in "${SC_AI_CACHE_TARGETS[@]}"; do
        if [ -e "${target}" ]; then
          sc_info "            $(sc_human_bytes "$(sc_du_bytes "${target}")") — ${target}"
        fi
      done
      sc_info "  Effect: Report-only. Cached app state may be downloadable, but this tool does not assume it is disposable."
      ;;
    codex-sessions)
      sc_info "  Evidence: Codex session history totals $(sc_human_bytes "${SC_CODEX_SESSION_BYTES}")."
      sc_info "  Effect: Task history is lost. Report-only and excluded from every cleanup package."
      ;;
    *)
      sc_warn "Unknown action: ${action}"
      return 1
      ;;
  esac
}

sc_package_actions() {
  case "${1}" in
    A|a)
      printf '%s\n' \
        docker-stopped-containers \
        docker-unused-images \
        docker-build-cache \
        dev-caches \
        simulator-unavailable-devices
      ;;
    B|b)
      printf '%s\n' \
        docker-stopped-containers \
        docker-unused-images \
        docker-build-cache \
        dev-caches \
        simulator-old-runtimes \
        simulator-unavailable-devices
      ;;
    *)
      return 1
      ;;
  esac
}

sc_contains_action() {
  local selected="$1"
  local wanted="$2"
  local action
  while IFS= read -r action; do
    [ "${action}" = "${wanted}" ] && return 0
  done <<EOF
${selected}
EOF
  return 1
}

sc_selected_action_count() {
  printf '%s\n' "${1:-}" | awk 'NF {count++} END {print count + 0}'
}

sc_configure_tm_thin_request() {
  local requested_gib="${1:-}"
  local urgency="${2:-}"
  local canonical_gib requested_bytes

  case "${requested_gib}" in
    ''|*[!0-9]*)
      sc_warn "Snapshot thinning target must be a whole number of GiB."
      return 1
      ;;
  esac
  canonical_gib="$(awk -v value="${requested_gib}" 'BEGIN {printf "%.0f", value + 0}')"
  if awk -v value="${canonical_gib}" 'BEGIN {exit !(value < 1)}'; then
    sc_warn "Snapshot thinning target must be at least 1 GiB."
    return 1
  fi
  case "${urgency}" in
    1|2|3|4) ;;
    *)
      sc_warn "Snapshot thinning urgency must be an integer from 1 to 4."
      return 1
      ;;
  esac

  requested_bytes="$(awk -v gib="${canonical_gib}" 'BEGIN {printf "%.0f", gib * 1073741824}')"
  case "${SC_DISK_TOTAL_BYTES}" in
    ''|*[!0-9]*|0)
      sc_warn "Audited disk capacity is unavailable; refusing to size a snapshot thinning request."
      return 1
      ;;
    *)
      if awk -v requested="${requested_bytes}" -v total="${SC_DISK_TOTAL_BYTES}" 'BEGIN {exit !(total > 0 && requested > total)}'; then
        sc_warn "Snapshot thinning target cannot exceed the audited disk capacity."
        return 1
      fi
      ;;
  esac

  SC_TM_THIN_GIB="${canonical_gib}"
  SC_TM_THIN_BYTES="${requested_bytes}"
  SC_TM_THIN_URGENCY="${urgency}"
  return 0
}

sc_validate_selected_policy() {
  local selected="$1"
  if sc_contains_action "${selected}" time-machine-thin; then
    if [ "$(sc_selected_action_count "${selected}")" -ne 1 ]; then
      sc_warn "Time Machine snapshot thinning must be reviewed and run by itself."
      return 1
    fi
    case "${SC_TM_SNAPSHOT_COUNT}" in
      ''|*[!0-9]*|0)
        sc_warn "Snapshot thinning requires a successful audit with at least one local Time Machine snapshot."
        return 1
        ;;
    esac
    if [ -z "${SC_TM_THIN_GIB}" ] || [ "${SC_TM_THIN_BYTES}" -le 0 ] || [ -z "${SC_TM_THIN_URGENCY}" ]; then
      sc_warn "Snapshot thinning parameters are incomplete."
      return 1
    fi
  fi
  return 0
}

sc_approval_phrase() {
  local selected="$1"
  local package_name="$2"
  if sc_contains_action "${selected}" time-machine-thin; then
    [ -n "${SC_TM_THIN_GIB}" ] || return 1
    printf 'THIN TIME MACHINE SNAPSHOTS %s GIB' "${SC_TM_THIN_GIB}"
  elif sc_contains_action "${selected}" docker-unused-volumes; then
    printf 'DELETE %s INCLUDING VOLUMES' "${package_name}"
  else
    printf 'DELETE %s' "${package_name}"
  fi
}

sc_action_preview_command() {
  local action="$1"
  case "${action}" in
    docker-stopped-containers) printf 'docker container prune --force' ;;
    docker-unused-images) printf 'docker image prune --all --force' ;;
    docker-build-cache) printf 'docker builder prune --all --force' ;;
    docker-unused-volumes) printf 'docker volume prune --all --force' ;;
    dev-caches) printf 'remove allowlisted developer cache directories only' ;;
    simulator-old-runtimes) printf 'xcrun simctl runtime delete <old-runtime-uuid>' ;;
    simulator-unavailable-devices) printf 'xcrun simctl delete unavailable' ;;
    time-machine-thin)
      if [ -n "${SC_TM_THIN_GIB}" ]; then
        printf 'tmutil thinlocalsnapshots / %s %s' "${SC_TM_THIN_BYTES}" "${SC_TM_THIN_URGENCY}"
      else
        printf 'tmutil thinlocalsnapshots / <approved-bytes> <urgency-1..4>'
      fi
      ;;
    *) printf 'report only' ;;
  esac
}

sc_show_plan() {
  local selected="$1"
  local action index=1 estimate_bytes total_bytes=0
  sc_info ""
  sc_info "Cleanup plan — NOTHING HAS RUN"
  while IFS= read -r action; do
    [ -n "${action}" ] || continue
    printf '  %d. [%s] %s — estimate %s\n' "${index}" "$(sc_action_risk "${action}")" "$(sc_action_label "${action}")" "$(sc_action_estimate "${action}")"
    printf '     %s\n' "$(sc_action_preview_command "${action}")"
    estimate_bytes="$(sc_action_estimate_bytes "${action}")"
    total_bytes=$((total_bytes + estimate_bytes))
    index=$((index + 1))
  done <<EOF
${selected}
EOF
  if sc_contains_action "${selected}" time-machine-thin; then
    sc_info "  Approved reclaim request: up to ${SC_TM_THIN_GIB} GiB (macOS may reclaim less)"
  else
    sc_info "  Approximate package total: $(sc_human_bytes "${total_bytes}")"
  fi
  sc_info ""
  if sc_contains_action "${selected}" time-machine-thin; then
    sc_info "Snapshot scope: local Time Machine snapshots only through tmutil; APFS update snapshots remain excluded."
  else
    sc_info "Explicit exclusions: Docker volumes (unless Custom), browser site data, Works source/data, Codex sessions, Photos, Mail, and macOS snapshots."
  fi
}

sc_is_executable_action() {
  local wanted="$1" action
  for action in "${SC_EXECUTABLE_ACTIONS[@]}"; do
    [ "${wanted}" = "${action}" ] && return 0
  done
  return 1
}

sc_custom_actions() {
  local answer token selected="" old_ifs requested_gib urgency
  SC_SELECTED_ACTIONS=""
  SC_TM_THIN_GIB=""
  SC_TM_THIN_BYTES=0
  SC_TM_THIN_URGENCY=""
  sc_info ""
  sc_info "Custom actions"
  sc_info "  1) Docker stopped containers       LOW"
  sc_info "  2) Docker unused images            LOW"
  sc_info "  3) Docker build cache              LOW"
  sc_info "  4) Developer caches                LOW"
  sc_info "  5) Old iOS runtimes                MEDIUM"
  sc_info "  6) Unavailable simulator devices   LOW"
  sc_info "  7) Docker unused volumes            HIGH"
  sc_info "  8) Time Machine snapshot thinning   HIGH (run alone)"
  printf 'Choose comma-separated numbers, or press Enter to cancel: '
  IFS= read -r answer
  [ -n "${answer}" ] || return 1

  answer="$(printf '%s' "${answer}" | tr -d '[:space:]')"
  case "${answer}" in
    *[!0-9,]*)
      sc_warn "Selection may contain digits and commas only."
      return 1
      ;;
  esac
  old_ifs="${IFS}"
  IFS=','
  set -- ${answer}
  IFS="${old_ifs}"
  for token in "$@"; do
    case "${token}" in
      1) selected="${selected}${selected:+
}docker-stopped-containers" ;;
      2) selected="${selected}${selected:+
}docker-unused-images" ;;
      3) selected="${selected}${selected:+
}docker-build-cache" ;;
      4) selected="${selected}${selected:+
}dev-caches" ;;
      5) selected="${selected}${selected:+
}simulator-old-runtimes" ;;
      6) selected="${selected}${selected:+
}simulator-unavailable-devices" ;;
      7) selected="${selected}${selected:+
}docker-unused-volumes" ;;
      8) selected="${selected}${selected:+
}time-machine-thin" ;;
      *) sc_warn "Ignored unknown selection: ${token}" ;;
    esac
  done
  [ -n "${selected}" ] || return 1

  if sc_contains_action "${selected}" time-machine-thin; then
    if [ "$(sc_selected_action_count "${selected}")" -ne 1 ]; then
      sc_warn "Time Machine snapshot thinning must be selected and run by itself."
      return 1
    fi
    case "${SC_TM_SNAPSHOT_COUNT}" in
      ''|*[!0-9]*|0)
        sc_warn "No auditable local Time Machine snapshot is available to thin."
        return 1
        ;;
    esac
    sc_warn "Apple normally manages local snapshots automatically. Thinning may remove local restore points."
    printf 'Maximum space to request in whole GiB: '
    IFS= read -r requested_gib
    printf 'Urgency (1=lowest, 4=highest): '
    IFS= read -r urgency
    sc_configure_tm_thin_request "${requested_gib}" "${urgency}" || return 1
  fi

  sc_validate_selected_policy "${selected}" || return 1
  SC_SELECTED_ACTIONS="${selected}"
}

sc_target_signature() {
  local selected="$1"
  {
    printf '%s\n' "${selected}"
    if sc_contains_action "${selected}" simulator-old-runtimes && [ -s "${SC_OLD_RUNTIME_FILE}" ]; then
      awk -F '|' '{print "runtime:" $3}' "${SC_OLD_RUNTIME_FILE}" | sort
    fi
    if sc_contains_action "${selected}" docker-unused-volumes && [ "${SC_DOCKER_READY}" -eq 1 ]; then
      docker volume ls -q -f dangling=true 2>/dev/null | sort | sed 's/^/volume:/'
    fi
    if sc_contains_action "${selected}" time-machine-thin; then
      printf 'tm-thin:%s:%s\n' "${SC_TM_THIN_BYTES}" "${SC_TM_THIN_URGENCY}"
      printf 'tm-count:%s\n' "${SC_TM_SNAPSHOT_COUNT}"
      if [ -n "${SC_TM_SNAPSHOT_FILE}" ] && [ -s "${SC_TM_SNAPSHOT_FILE}" ]; then
        sort "${SC_TM_SNAPSHOT_FILE}" | sed 's/^/snapshot:/'
      fi
    fi
  } | shasum -a 256 | awk '{print $1}'
}

sc_is_allowed_cache_target() {
  local candidate="$1" allowed
  for allowed in "${SC_DIRECT_CACHE_TARGETS[@]}"; do
    [ "${candidate}" = "${allowed}" ] && return 0
  done
  return 1
}

sc_run_logged() {
  local status
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  if [ -n "${SC_EXEC_LOG}" ]; then
    {
      printf '+'
      printf ' %q' "$@"
      printf '\n'
    } >> "${SC_EXEC_LOG}"
    "$@" 2>&1 | tee -a "${SC_EXEC_LOG}"
    status=${PIPESTATUS[0]}
  else
    "$@"
    status=$?
  fi
  return "${status}"
}

sc_remove_cache_target() {
  local target="$1"
  if ! sc_is_allowed_cache_target "${target}"; then
    sc_warn "Refusing non-allowlisted cache path: ${target}"
    return 1
  fi
  case "${target}" in
    "${SC_USER_HOME}"/*) ;;
    *) sc_warn "Refusing cache path outside user home: ${target}"; return 1 ;;
  esac
  if [ -L "${target}" ]; then
    sc_warn "Refusing symlink cache target: ${target}"
    return 1
  fi
  if [ ! -e "${target}" ]; then
    sc_info "Skip missing cache: ${target}"
    return 0
  fi
  sc_run_logged /bin/rm -rf "${target}"
}

sc_execute_dev_caches() {
  local target failed=0

  if [ -e "${SC_GO_MODULE_CACHE}" ] || [ -e "${SC_GO_BUILD_CACHE}" ]; then
    if sc_have go; then
      sc_run_logged go clean -modcache -cache -testcache || failed=1
    else
      sc_warn "Go is unavailable; read-only Go caches were skipped instead of changing permissions."
      failed=1
    fi
  fi

  for target in "${SC_DIRECT_CACHE_TARGETS[@]}"; do
    sc_remove_cache_target "${target}" || failed=1
  done
  return "${failed}"
}

sc_execute_old_runtimes() {
  local version build uuid reported runtime_identifier failed=0
  if [ ! -s "${SC_OLD_RUNTIME_FILE}" ]; then
    sc_info "No old iOS runtime selected by policy."
    return 0
  fi
  while IFS='|' read -r version build uuid reported; do
    [ -n "${uuid}" ] || continue
    runtime_identifier="$(sc_runtime_device_key "${version}")"
    sc_info "Removing iOS ${version} (${build}); keeping iOS ${SC_SIM_LATEST_VERSION}."
    sc_run_logged xcrun simctl runtime dyld_shared_cache remove "${runtime_identifier}" || sc_warn "Could not remove dyld cache separately; runtime deletion will continue."
    sc_run_logged xcrun simctl runtime delete "${uuid}" || failed=1
  done < "${SC_OLD_RUNTIME_FILE}"
  return "${failed}"
}

sc_execute_time_machine_thin() {
  if ! sc_have tmutil; then
    sc_warn "tmutil is unavailable; snapshot thinning was not attempted."
    return 1
  fi
  if [ -z "${SC_TM_THIN_GIB}" ] || [ "${SC_TM_THIN_BYTES}" -le 0 ]; then
    sc_warn "Snapshot thinning parameters are missing; refusing execution."
    return 1
  fi
  case "${SC_TM_SNAPSHOT_COUNT}" in
    ''|*[!0-9]*|0)
      sc_warn "No audited local Time Machine snapshot remains eligible; refusing execution."
      return 1
      ;;
  esac
  if [ -z "${SC_TM_SNAPSHOT_FILE}" ] || [ ! -s "${SC_TM_SNAPSHOT_FILE}" ]; then
    sc_warn "Approved snapshot inventory is unavailable; refusing execution."
    return 1
  fi

  sc_info "Local Time Machine snapshots before thinning:"
  if ! sc_run_logged tmutil listlocalsnapshots /; then
    sc_warn "Could not re-list local snapshots; thinning was not attempted."
    return 1
  fi

  sc_info "Requesting up to ${SC_TM_THIN_GIB} GiB at urgency ${SC_TM_THIN_URGENCY}."
  if ! sc_run_logged tmutil thinlocalsnapshots / "${SC_TM_THIN_BYTES}" "${SC_TM_THIN_URGENCY}"; then
    sc_warn "tmutil could not thin local snapshots. This tool will not invoke sudo automatically."
    sc_warn "Review Full Disk Access and the logged command before deciding whether to run it manually."
    return 1
  fi

  sc_info "Local Time Machine snapshots after thinning:"
  if ! sc_run_logged tmutil listlocalsnapshots /; then
    sc_warn "Thinning completed, but the post-action snapshot inventory could not be read."
    return 1
  fi
  return 0
}

sc_execute_action() {
  case "$1" in
    docker-stopped-containers)
      [ "${SC_DOCKER_READY}" -eq 1 ] || { sc_warn "Docker unavailable; skipped stopped containers."; return 1; }
      sc_run_logged docker container prune --force
      ;;
    docker-unused-images)
      [ "${SC_DOCKER_READY}" -eq 1 ] || { sc_warn "Docker unavailable; skipped unused images."; return 1; }
      sc_run_logged docker image prune --all --force
      ;;
    docker-build-cache)
      [ "${SC_DOCKER_READY}" -eq 1 ] || { sc_warn "Docker unavailable; skipped build cache."; return 1; }
      sc_run_logged docker builder prune --all --force
      ;;
    docker-unused-volumes)
      [ "${SC_DOCKER_READY}" -eq 1 ] || { sc_warn "Docker unavailable; skipped volumes."; return 1; }
      if ! docker volume prune --help 2>/dev/null | grep -q -- '--all'; then
        sc_warn "This Docker version cannot explicitly prune all unused named volumes; refusing partial cleanup."
        return 1
      fi
      sc_run_logged docker volume prune --all --force
      ;;
    dev-caches)
      sc_execute_dev_caches
      ;;
    simulator-old-runtimes)
      sc_execute_old_runtimes
      ;;
    simulator-unavailable-devices)
      sc_run_logged xcrun simctl delete unavailable
      ;;
    time-machine-thin)
      sc_execute_time_machine_thin
      ;;
    *)
      sc_warn "Refusing unknown action: $1"
      return 1
      ;;
  esac
}

sc_execute_selected() {
  local selected="$1" action failed=0
  while IFS= read -r action; do
    [ -n "${action}" ] || continue
    if ! sc_is_executable_action "${action}"; then
      sc_warn "Refusing non-executable action: ${action}"
      failed=1
      continue
    fi
    sc_info ""
    sc_info "==> $(sc_action_label "${action}")"
    sc_execute_action "${action}" || failed=1
  done <<EOF
${selected}
EOF
  return "${failed}"
}

sc_run_interactive() {
  local choice selected package_name approval_phrase confirmation
  local signature_before signature_after before_free after_free delta status=0
  local log_dir

  [ "$(uname -s)" = "Darwin" ] || sc_die "This program supports macOS only."
  [ "$(id -u)" -ne 0 ] || sc_die "Do not run this program as root or with sudo."
  [ -t 0 ] || sc_die "Interactive cleanup requires a terminal. Audit/plan commands remain non-destructive."

  sc_collect_facts
  sc_print_audit_summary
  sc_print_reason_matrix

  sc_info ""
  sc_info "Options"
  sc_info "  A) Conservative: Docker non-volume reclaim + developer caches + unavailable simulators"
  sc_info "  B) Package B: A + old iOS runtimes; newest iOS ${SC_SIM_LATEST_VERSION} is kept"
  sc_info "  C) Custom: individual actions; Docker volumes and Time Machine thinning are HIGH risk"
  sc_info "  Q) Quit without changes"
  printf 'Choose an option: '
  IFS= read -r choice

  case "${choice}" in
    A|a)
      selected="$(sc_package_actions A)"
      package_name="PACKAGE-A"
      ;;
    B|b)
      selected="$(sc_package_actions B)"
      package_name="PACKAGE-B"
      ;;
    C|c)
      sc_custom_actions || { sc_info "Cancelled; nothing changed."; return 0; }
      selected="${SC_SELECTED_ACTIONS}"
      package_name="CUSTOM"
      ;;
    *)
      sc_info "Cancelled; nothing changed."
      return 0
      ;;
  esac

  sc_validate_selected_policy "${selected}" || { sc_info "Cancelled; nothing changed."; return 0; }

  sc_show_plan "${selected}"
  sc_info ""
  sc_warn "Close Xcode/Simulator and active build processes before continuing."
  sc_warn "Docker volumes, Time Machine snapshots, browser site data, Works data, and Codex sessions are excluded unless explicitly shown above."
  if sc_contains_action "${selected}" time-machine-thin; then
    sc_warn "Local snapshots are restore points and macOS normally manages them automatically."
  fi

  signature_before="$(sc_target_signature "${selected}")"
  approval_phrase="$(sc_approval_phrase "${selected}" "${package_name}")" || sc_die "Could not build the approval phrase."

  sc_info ""
  sc_info "To approve this exact plan, type: ${approval_phrase}"
  printf '> '
  IFS= read -r confirmation
  if [ "${confirmation}" != "${approval_phrase}" ]; then
    sc_info "Approval did not match; nothing changed."
    return 0
  fi

  sc_run_phase "Revalidating destructive Simulator targets" sc_collect_simulator
  if sc_contains_action "${selected}" time-machine-thin; then
    sc_run_phase "Revalidating Time Machine snapshot targets" sc_collect_disk
    sc_validate_selected_policy "${selected}" || sc_die "Time Machine snapshot targets are no longer eligible. Run the audit again."
  fi
  signature_after="$(sc_target_signature "${selected}")"
  if [ "${signature_before}" != "${signature_after}" ]; then
    sc_die "Targets changed after review. Run the program again and review the new plan."
  fi

  log_dir="${SC_USER_HOME}/Library/Logs/storage-clearer"
  mkdir -p "${log_dir}" || sc_die "Cannot create log directory: ${log_dir}"
  SC_EXEC_LOG="${log_dir}/cleanup-$(date '+%Y%m%d-%H%M%S').log"
  before_free="${SC_DISK_FREE_BYTES}"

  sc_info "Execution log: ${SC_EXEC_LOG}"
  sc_execute_selected "${selected}" || status=1

  sc_collect_disk
  after_free="${SC_DISK_FREE_BYTES}"
  delta=$((after_free - before_free))
  sc_info ""
  sc_info "Cleanup finished with status ${status}."
  sc_info "Free space before: $(sc_human_bytes "${before_free}")"
  sc_info "Free space after:  $(sc_human_bytes "${after_free}")"
  if [ "${delta}" -ge 0 ]; then
    sc_info "Host space gained: $(sc_human_bytes "${delta}")"
  else
    sc_info "Host free-space delta: -$(sc_human_bytes "$((-delta))") (active workloads may have written data during cleanup)"
  fi
  sc_info "Docker.raw may release host blocks later after Docker Desktop performs TRIM/compaction."
  return "${status}"
}

sc_usage() {
  cat <<'EOF'
macOS Storage Clearer

Usage:
  ./storage-clearer.sh audit
  ./storage-clearer.sh explain [all|ACTION-ID]
  ./storage-clearer.sh reason [all|ACTION-ID]
  ./storage-clearer.sh plan [A|B]
  ./storage-clearer.sh run
  ./storage-clearer.sh help

Safety model:
  - audit, explain, and plan are read-only.
  - run is interactive and requires an exact typed approval phrase.
  - the program refuses to run cleanup as root.
  - Package A/B never delete Docker volumes, browser site data, Works data,
    Codex sessions, Photos, Mail, or macOS snapshots.
  - Time Machine thinning is Custom-only, runs alone, and uses tmutil without
    automatic sudo or direct snapshot deletion.
EOF
}

sc_main() {
  local command="${1:-audit}"
  local subject action selected
  case "${command}" in
    audit)
      sc_collect_facts
      sc_print_audit_summary
      sc_print_reason_matrix
      ;;
    explain|reason|explore)
      subject="${2:-all}"
      sc_collect_facts
      if [ "${subject}" = "all" ]; then
        for action in "${SC_MATRIX_ACTIONS[@]}"; do
          sc_explain_action "${action}"
        done
      else
        sc_explain_action "${subject}"
      fi
      ;;
    plan)
      subject="${2:-B}"
      selected="$(sc_package_actions "${subject}")" || sc_die "Unknown package: ${subject}"
      sc_collect_facts
      sc_print_audit_summary
      sc_print_reason_matrix
      sc_show_plan "${selected}"
      ;;
    run)
      sc_run_interactive
      ;;
    help|-h|--help)
      sc_usage
      ;;
    version|--version)
      printf '%s\n' "${SC_VERSION}"
      ;;
    *)
      sc_usage
      sc_die "Unknown command: ${command}"
      ;;
  esac
}

if [ "${SC_SKIP_MAIN:-0}" != "1" ]; then
  sc_main "$@"
fi
