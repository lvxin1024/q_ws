#!/usr/bin/env bash
set -euo pipefail

WS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_CANDIDATES=(
  "$WS_DIR/src/tamer/bin"
  "$WS_DIR/src/RoboTamer4Qmini/bin"
)

BIN_DIR=""
for d in "${BIN_CANDIDATES[@]}"; do
  if [[ -f "$d/run_interface" && ! -x "$d/run_interface" ]]; then
    chmod +x "$d/run_interface" || true
  fi
  if [[ -x "$d/run_interface" ]]; then
    BIN_DIR="$d"
    break
  fi
done

EXE="$BIN_DIR/run_interface"

EXPECTED_IFACES=(if00 if01 if02 if03)

select_net_iface() {
  local preferred=("${TAMER_NET_IFACE:-}" eth0 wlan0)
  local iface state

  for iface in "${preferred[@]}"; do
    [[ -z "$iface" ]] && continue
    if [[ -e "/sys/class/net/$iface" ]]; then
      state="$(cat "/sys/class/net/$iface/operstate" 2>/dev/null || true)"
      if [[ "$state" == "up" ]]; then
        echo "$iface"
        return 0
      fi
    fi
  done

  for iface_path in /sys/class/net/*; do
    iface="$(basename "$iface_path")"
    [[ "$iface" == "lo" ]] && continue
    state="$(cat "$iface_path/operstate" 2>/dev/null || true)"
    if [[ "$state" == "up" ]]; then
      echo "$iface"
      return 0
    fi
  done

  if [[ -n "${TAMER_NET_IFACE:-}" ]]; then
    echo "$TAMER_NET_IFACE"
  else
    echo "eth0"
  fi
}

if [[ -z "$BIN_DIR" || ! -x "$EXE" ]]; then
  echo "[ERROR] Missing executable: run_interface" >&2
  echo "[INFO] Tried paths:" >&2
  for d in "${BIN_CANDIDATES[@]}"; do
    echo "  - $d/run_interface" >&2
  done
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
for iface in "${EXPECTED_IFACES[@]}"; do
  if ! compgen -G "/dev/serial/by-id/usb-FTDI_USB__-__Serial_Converter_*-${iface}-port0" > /dev/null; then
    echo "[ERROR] Missing motor serial interface: ${iface}" >&2
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  echo "[INFO] Current /dev/serial/by-id entries:" >&2
  ls -la /dev/serial/by-id >&2 || true
  echo "[HINT] Check USB cable/hub/power and re-plug motor serial adapter." >&2
  echo "[HINT] You can inspect current devices with: ls -la /dev/serial/by-id" >&2
  exit 2
fi

echo "[INFO] Preflight passed. Launching RoboTamer..."
cd "$BIN_DIR"
NET_IFACE="$(select_net_iface)"
echo "[INFO] Using network interface: $NET_IFACE"
exec env PYTHONPATH="$BIN_DIR:${PYTHONPATH:-}" ./run_interface "$NET_IFACE"
