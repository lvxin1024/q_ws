#!/usr/bin/env bash
set -euo pipefail

WS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$WS_DIR/src/RoboTamer4Qmini/bin"
EXE="$BIN_DIR/run_interface"

EXPECTED_PORTS=(
  "/dev/serial/by-id/usb-FTDI_USB__-__Serial_Converter_FT9CC6WH-if03-port0"
  "/dev/serial/by-id/usb-FTDI_USB__-__Serial_Converter_FT9CC6WH-if01-port0"
  "/dev/serial/by-id/usb-FTDI_USB__-__Serial_Converter_FT9CC6WH-if00-port0"
  "/dev/serial/by-id/usb-FTDI_USB__-__Serial_Converter_FT9CC6WH-if02-port0"
)

if [[ ! -x "$EXE" ]]; then
  echo "[ERROR] Missing executable: $EXE" >&2
  echo "[HINT] Run: ./build_all.sh" >&2
  exit 1
fi

for f in "$BIN_DIR/joystick.py" "$BIN_DIR/imu_interface.py" "$BIN_DIR/policy.onnx" "$BIN_DIR/config.yaml"; do
  if [[ ! -f "$f" ]]; then
    echo "[ERROR] Missing runtime file: $f" >&2
    exit 1
  fi
done

if [[ ! -d /dev/serial/by-id ]]; then
  echo "[ERROR] /dev/serial/by-id does not exist." >&2
  echo "[HINT] Motor USB serial devices are not detected yet." >&2
  exit 2
fi

missing=0
for p in "${EXPECTED_PORTS[@]}"; do
  if [[ ! -e "$p" ]]; then
    echo "[ERROR] Missing motor serial device: $p" >&2
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  echo "[HINT] Check USB cable/hub/power and re-plug motor serial adapter." >&2
  echo "[HINT] You can inspect current devices with: ls -la /dev/serial/by-id" >&2
  exit 2
fi

echo "[INFO] Preflight passed. Launching RoboTamer..."
cd "$BIN_DIR"
exec sudo -E env PYTHONPATH="$BIN_DIR:${PYTHONPATH:-}" ./run_interface
