#!/usr/bin/env bash
set -euo pipefail

WS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$WS_DIR"

if ! command -v colcon >/dev/null 2>&1; then
  echo "[ERROR] colcon not found. Please install python3-colcon-common-extensions first." >&2
  exit 1
fi

PKGS="$(colcon list --base-paths src --names-only)"
if [[ -z "$PKGS" ]]; then
  echo "[ERROR] No colcon packages found under $WS_DIR/src" >&2
  exit 1
fi

echo "[INFO] Packages to build:"
echo "$PKGS" | sed 's/^/  - /'

SPDLOG_FOUND=0
FMT_FOUND=0
if [[ -f /usr/include/spdlog/spdlog.h || -f /usr/local/include/spdlog/spdlog.h ]]; then
  SPDLOG_FOUND=1
fi
if [[ -f /usr/include/fmt/format.h || -f /usr/local/include/fmt/format.h ]]; then
  FMT_FOUND=1
fi

if [[ "$SPDLOG_FOUND" -eq 1 && "$FMT_FOUND" -eq 1 ]]; then
  echo "[INFO] spdlog/fmt found. Build all packages with default settings."
  echo "[INFO] Use --cmake-clean-cache to avoid stale CMake cache conflicts."
  colcon build --base-paths src --cmake-clean-cache "$@"
else
  echo "[WARN] spdlog/fmt not fully found."
  echo "[WARN] Build unitree_sdk2 with examples disabled to avoid missing-header failures."
  echo "[INFO] Use --cmake-clean-cache to avoid stale CMake cache conflicts."

  if echo "$PKGS" | grep -qx "unitree_sdk2"; then
    echo "[INFO] Build non-unitree_sdk2 packages first (default settings)."
    colcon build --base-paths src --cmake-clean-cache --packages-skip unitree_sdk2 "$@"

    echo "[INFO] Build unitree_sdk2 only with BUILD_EXAMPLES=OFF."
    colcon build --base-paths src --cmake-clean-cache --packages-select unitree_sdk2 --cmake-args -DBUILD_EXAMPLES=OFF "$@"
  else
    echo "[INFO] unitree_sdk2 not found in workspace. Build all packages with default settings."
    colcon build --base-paths src --cmake-clean-cache "$@"
  fi
fi

EXPECTED="$(colcon list --base-paths src --names-only | sort)"
ACTUAL="$(find install -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort || true)"
MISSING="$(comm -23 <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$ACTUAL") || true)"

if [[ -z "$MISSING" ]]; then
  echo "[OK] All detected packages have install directories."
else
  echo "[WARN] Some packages are missing from install/:"
  echo "$MISSING" | sed 's/^/  - /'
  exit 2
fi
