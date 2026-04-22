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
ZIP_PATH="${DIST_DIR}/ClaudePetty.zip"

rm -rf "${DIST_DIR}" "${BUILD_DIR}"
mkdir -p "${DIST_DIR}"

echo "=== Building arm64 ==="
xcodebuild build \
  -project ClaudeDash.xcodeproj \
  -scheme ClaudeDash \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_DIR}-arm64" \
  -destination 'platform=macOS' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES

echo "=== Building x86_64 ==="
xcodebuild build \
  -project ClaudeDash.xcodeproj \
  -scheme ClaudeDash \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_DIR}-x86_64" \
  -destination 'platform=macOS' \
  ARCHS=x86_64 \
  ONLY_ACTIVE_ARCH=YES

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

verify_binary_arch() {
  local binary_path="$1"
  local expected_arch="$2"
  local actual_archs

  actual_archs="$(lipo -archs "${binary_path}" 2>/dev/null || true)"

  if [[ " ${actual_archs} " != *" ${expected_arch} "* ]]; then
    echo "Expected ${binary_path} to contain architecture ${expected_arch}, but got:" >&2
    lipo -info "${binary_path}" >&2 || true
    exit 1
  fi
}

sign_dist_app() {
  echo "=== Re-signing merged app bundle ==="
  codesign --force --sign - --timestamp=none "${APP_DIST_PATH}/Contents/Resources/ClaudeDashHelper"
  codesign --force --sign - --timestamp=none "${APP_DIST_PATH}"
}

verify_dist_app_signature() {
  echo "=== Verifying app bundle signature ==="
  codesign --verify --deep --strict --verbose=4 "${APP_DIST_PATH}"
}

verify_binary_arch "${ARM64_APP}/Contents/MacOS/ClaudeGlance" arm64
verify_binary_arch "${ARM64_APP}/Contents/Resources/ClaudeDashHelper" arm64
verify_binary_arch "${X86_APP}/Contents/MacOS/ClaudeGlance" x86_64
verify_binary_arch "${X86_APP}/Contents/Resources/ClaudeDashHelper" x86_64

# Merge main executable
merge_binary \
  "${X86_APP}/Contents/MacOS/ClaudeGlance" \
  "${APP_DIST_PATH}/Contents/MacOS/ClaudeGlance"

# Merge helper executable
merge_binary \
  "${X86_APP}/Contents/Resources/ClaudeDashHelper" \
  "${APP_DIST_PATH}/Contents/Resources/ClaudeDashHelper"

# Verify universal binary
echo "=== Verifying universal binary ==="
lipo -info "${APP_DIST_PATH}/Contents/MacOS/ClaudeGlance"

sign_dist_app
verify_dist_app_signature

echo "=== Creating ZIP ==="
ditto -c -k --sequesterRsrc --keepParent "${APP_DIST_PATH}" "${ZIP_PATH}"

echo
echo "Built artifacts:"
ls -la "${DIST_DIR}"
echo
echo "SHA-256:"
shasum -a 256 "${ZIP_PATH}"
