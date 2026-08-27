#!/bin/bash

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${1:-${PROJECT_DIR}/dist}"
APP_BUNDLE="${OUTPUT_DIR}/Storage Clearer.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

cd "${PROJECT_DIR}"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

case "${APP_BUNDLE}" in
  "${OUTPUT_DIR}/Storage Clearer.app") ;;
  *)
    printf 'Refusing unexpected app bundle path: %s\n' "${APP_BUNDLE}" >&2
    exit 1
    ;;
esac

/bin/rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_DIR}/StorageClearerApp" "${MACOS_DIR}/StorageClearerApp"
cp "${PROJECT_DIR}/storage-clearer.sh" "${RESOURCES_DIR}/storage-clearer.sh"
cp "${PROJECT_DIR}/App/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${PROJECT_DIR}/App/Assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
chmod 755 "${MACOS_DIR}/StorageClearerApp" "${RESOURCES_DIR}/storage-clearer.sh"

printf 'Built %s\n' "${APP_BUNDLE}"
printf 'The bundle is unsigned. Sign and notarize it before external distribution.\n'
