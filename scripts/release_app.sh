#!/bin/bash

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RELEASE_DIR="${1:-${PROJECT_DIR}/dist/releases}"
DEVELOPER_ID="${SC_DEVELOPER_ID:-}"
NOTARY_PROFILE="${SC_NOTARY_PROFILE:-}"

if [ -z "${DEVELOPER_ID}" ]; then
  printf 'SC_DEVELOPER_ID is required, for example: Developer ID Application: Name (TEAMID)\n' >&2
  exit 1
fi

if [ -z "${NOTARY_PROFILE}" ]; then
  printf 'SC_NOTARY_PROFILE is required. Create one with xcrun notarytool store-credentials.\n' >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PROJECT_DIR}/App/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${PROJECT_DIR}/App/Info.plist")"
RELEASE_NAME="Storage-Clearer-${VERSION}-arm64"
TEMP_DIR="$(mktemp -d /tmp/storage-clearer-release.XXXXXX)"
APP_BUNDLE="${TEMP_DIR}/Storage Clearer.app"
ARCHIVE_PATH="${RELEASE_DIR}/${RELEASE_NAME}.zip"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

cleanup() {
  /bin/rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${RELEASE_DIR}"
"${SCRIPT_DIR}/package_app.sh" "${TEMP_DIR}"

codesign --force --options runtime --timestamp --sign "${DEVELOPER_ID}" "${APP_BUNDLE}/Contents/MacOS/StorageClearerApp"
codesign --force --options runtime --timestamp --sign "${DEVELOPER_ID}" "${APP_BUNDLE}"
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

SUBMISSION_ARCHIVE="${TEMP_DIR}/${RELEASE_NAME}-notary.zip"
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${SUBMISSION_ARCHIVE}"
xcrun notarytool submit "${SUBMISSION_ARCHIVE}" --keychain-profile "${NOTARY_PROFILE}" --wait
xcrun stapler staple "${APP_BUNDLE}"
xcrun stapler validate "${APP_BUNDLE}"
spctl --assess --type execute --verbose=2 "${APP_BUNDLE}"

ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ARCHIVE_PATH}"
shasum -a 256 "${ARCHIVE_PATH}" > "${CHECKSUM_PATH}"

printf 'Release ready: %s\n' "${ARCHIVE_PATH}"
printf 'Checksum: %s\n' "${CHECKSUM_PATH}"
printf 'Version: %s (%s)\n' "${VERSION}" "${BUILD_NUMBER}"
