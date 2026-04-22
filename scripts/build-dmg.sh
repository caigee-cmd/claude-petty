#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

APP_NAME="ClaudeGlance.app"
DMG_TITLE="Claude Glance"
DIST_DIR="${REPO_ROOT}/dist"
APP_PATH="${DIST_DIR}/${APP_NAME}"
TOOLS_DIR="${REPO_ROOT}/.tools/create-dmg"
NODE_VERSION_FILE="${TOOLS_DIR}/.node-version"

find_node_bin() {
  local candidate
  local major

  if command -v node >/dev/null 2>&1; then
    candidate="$(command -v node)"
    major="$("${candidate}" -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
    if [[ "${major}" -ge 18 ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi

  while IFS= read -r candidate; do
    printf '%s\n' "${candidate}"
    return 0
  done < <(find "${HOME}/.nvm/versions/node" -path '*/v20.*/bin/node' -type f 2>/dev/null | sort -Vr)

  while IFS= read -r candidate; do
    printf '%s\n' "${candidate}"
    return 0
  done < <(find "${HOME}/.nvm/versions/node" -path '*/v22.*/bin/node' -type f 2>/dev/null | sort -Vr)

  while IFS= read -r candidate; do
    printf '%s\n' "${candidate}"
    return 0
  done < <(find "${HOME}/.nvm/versions/node" -path '*/v18.*/bin/node' -type f 2>/dev/null | sort -Vr)

  while IFS= read -r candidate; do
    major="$("${candidate}" -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
    if [[ "${major}" -ge 18 ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done < <(find "${HOME}/.nvm/versions/node" -path '*/bin/node' -type f 2>/dev/null | sort -Vr)

  return 1
}

NODE_BIN="$(find_node_bin || true)"

if [[ -z "${NODE_BIN}" ]]; then
  echo "Node.js 18+ is required to run create-dmg." >&2
  echo "Install a newer Node.js runtime or make one available via ~/.nvm." >&2
  exit 1
fi

NODE_PREFIX="$(cd "$(dirname "${NODE_BIN}")/.." && pwd)"
NPM_CLI="${NODE_PREFIX}/lib/node_modules/npm/bin/npm-cli.js"
CREATE_DMG_CLI="${TOOLS_DIR}/node_modules/create-dmg/cli.js"
NODE_VERSION="$("${NODE_BIN}" -p 'process.versions.node')"
NODE_BASENAME="$(basename "$(cd "$(dirname "${NODE_BIN}")/.." && pwd)")"

ensure_valid_release_app() {
  if codesign --verify --deep --strict --verbose=4 "${APP_PATH}" >/dev/null 2>&1; then
    return 0
  fi

  echo "Release app signature is invalid at ${APP_PATH}. Rebuilding release artifacts..."
  "${SCRIPT_DIR}/build-release.sh"
  codesign --verify --deep --strict --verbose=4 "${APP_PATH}"
}

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Release app not found at ${APP_PATH}. Building release artifacts first..."
  "${SCRIPT_DIR}/build-release.sh"
fi

ensure_valid_release_app

if ! command -v gm >/dev/null 2>&1; then
  echo "GraphicsMagick is required for a good-looking DMG icon." >&2
  echo "Install it with: brew install graphicsmagick" >&2
  exit 1
fi

if [[ ! -f "${CREATE_DMG_CLI}" ]] || [[ ! -f "${NODE_VERSION_FILE}" ]] || [[ "$(cat "${NODE_VERSION_FILE}")" != "${NODE_VERSION}" ]]; then
  echo "Installing create-dmg into ${TOOLS_DIR}..."
  rm -rf "${TOOLS_DIR}"
  mkdir -p "${TOOLS_DIR}"

  if [[ "${NODE_BIN}" == "${HOME}"/.nvm/versions/node/*/bin/node ]] && [[ -f "${HOME}/.nvm/nvm.sh" ]]; then
    export TOOLS_DIR NODE_BASENAME
    bash -lc 'source "${HOME}/.nvm/nvm.sh" && nvm use "${NODE_BASENAME}" >/dev/null && npm --prefix "${TOOLS_DIR}" install --no-fund --no-audit create-dmg'
  else
    PATH="$(dirname "${NODE_BIN}"):${PATH}" "${NODE_BIN}" "${NPM_CLI}" --prefix "${TOOLS_DIR}" install --no-fund --no-audit create-dmg
  fi

  printf '%s\n' "${NODE_VERSION}" > "${NODE_VERSION_FILE}"
fi

"${NODE_BIN}" "${CREATE_DMG_CLI}" \
  --overwrite \
  --no-code-sign \
  --dmg-title="${DMG_TITLE}" \
  --dmg-name="ClaudePetty" \
  "${APP_PATH}" \
  "${DIST_DIR}"

echo
echo "DMG artifact:"
ls -lh "${DIST_DIR}"/*.dmg
