#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

APP_NAME="ClaudeGlance.app"
DIST_DIR="${REPO_ROOT}/dist"
BUILD_DIR="${REPO_ROOT}/build"
DERIVED_DATA_DIR="${BUILD_DIR}/DerivedData"
APP_DIST_PATH="${DIST_DIR}/${APP_NAME}"
ZIP_PATH="${DIST_DIR}/ClaudeGlance.zip"

rm -rf "${DIST_DIR}" "${BUILD_DIR}"
mkdir -p "${DIST_DIR}"

echo "=== Building arm64 ==="
xcodebuild build \
  -project ClaudeDash.xcodeproj \
  -scheme ClaudeDash \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_DIR}-arm64" \
  -destination 'platform=macOS,arch=arm64'

echo "=== Building x86_64 ==="
xcodebuild build \
  -project ClaudeDash.xcodeproj \
  -scheme ClaudeDash \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_DIR}-x86_64" \
  -destination 'platform=macOS,arch=x86_64'

ARM64_APP="${DERIVED_DATA_DIR}-arm64/Build/Products/Release/${APP_NAME}"
X86_APP="${DERIVED_DATA_DIR}-x86_64/Build/Products/Release/${APP_NAME}"

if [[ ! -d "${ARM64_APP}" ]] || [[ ! -d "${X86_APP}" ]]; then
  echo "Build failed: arm64 or x86_64 app not found" >&2
  exit 1
fi

echo "=== Copying arm64 app as base ==="
ditto "${ARM64_APP}" "${APP_DIST_PATH}"

echo "=== Merging x86_64 into universal ==="
merge_binary() {
  local src="$1"
  local dst="$2"
  if [[ -f "${src}" ]]; then
    lipo "${src}" "${dst}" -output "${dst}" -create
  fi
}

# Merge main executable
merge_binary \
  "${X86_APP}/Contents/MacOS/ClaudeGlance" \
  "${APP_DIST_PATH}/Contents/MacOS/ClaudeGlance"

# Merge helper executable
merge_binary \
  "${X86_APP}/Contents/MacOS/ClaudeDashHelper" \
  "${APP_DIST_PATH}/Contents/MacOS/ClaudeDashHelper"

# Verify universal binary
echo "=== Verifying universal binary ==="
lipo -info "${APP_DIST_PATH}/Contents/MacOS/ClaudeGlance"

echo "=== Creating ZIP ==="
ditto -c -k --sequesterRsrc --keepParent "${APP_DIST_PATH}" "${ZIP_PATH}"

echo
echo "Built artifacts:"
ls -la "${DIST_DIR}"
echo
echo "SHA-256:"
shasum -a 256 "${ZIP_PATH}"
