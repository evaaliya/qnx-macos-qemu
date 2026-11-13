#!/usr/bin/env bash
# One command: host checks, Docker, QNX packages, SSH key, image, QEMU, SSH, example.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

qnx_info "1/8 Host doctor"
"$ROOT/scripts/doctor.sh"

qnx_info "2/8 Docker build environment"
"$ROOT/scripts/setup-docker.sh"

qnx_info "3/8 QNX target packages"
"$ROOT/scripts/check-prereqs.sh"

qnx_info "4/8 SSH key"
"$ROOT/scripts/ensure-ssh-key.sh"

qnx_info "5/8 QEMU image"
if [[ -f "$QNX_TARGET_DIR/output/ifs.bin" && -f "$QNX_TARGET_DIR/output/disk-qemu.vmdk" ]]; then
  echo "OK   image already built: $QNX_TARGET_DIR/output/ifs.bin"
else
  echo "Image is missing. Building it (this can take several minutes)."
  "$ROOT/scripts/build-image.sh"
fi

qnx_info "6/8 QEMU"
if qnx_qemu_running; then
  echo "OK   QEMU already running (pid $(qnx_qemu_pid))"
else
  if [[ -e "$QNX_TARGET_DIR/output/qemu.pid" ]]; then
    rm -f "$QNX_TARGET_DIR/output/qemu.pid"
  fi
  if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$QNX_SSH_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    qnx_die "TCP port $QNX_SSH_PORT is already in use. Free it, or stop the other QEMU, then re-run."
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    qnx_die "python3 is required to detach QEMU so it keeps running after this script exits."
  fi
  mkdir -p "$QNX_TARGET_DIR/output"
  : >"$QNX_TARGET_DIR/output/serial.log"
  qnx_info "Starting qemu-system-aarch64 (serial log: $QNX_TARGET_DIR/output/serial.log)"
  # A new session, not nohup alone. Otherwise the process is killed with this shell's
  # process group when ./scripts/up.sh returns.
  python3 - "$QNX_TARGET_DIR" "$ROOT/qemu-aarch64le/run.sh" "$QNX_TARGET_DIR/output/qemu.host.log" <<'PY' &
import os, sys
target, script, log = sys.argv[1:]
os.setsid()
logfd = os.open(log, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
os.dup2(logfd, 1)
os.dup2(logfd, 2)
if logfd > 2:
    os.close(logfd)
devnull = os.open("/dev/null", os.O_RDONLY)
os.dup2(devnull, 0)
if devnull > 2:
    os.close(devnull)
os.environ["TARGET_DIR"] = target
os.execv(script, [script])
PY
  qemu_launch_pid=$!
  disown || true
fi

qnx_info "7/8 Waiting for SSH on localhost:$QNX_SSH_PORT"
qemu_launch_pid="${qemu_launch_pid:-0}"
i=0
ssh_up=0
while [[ "$i" -lt 90 ]]; do
  i=$((i + 1))
  if qnx_ssh true >/dev/null 2>&1; then
    ssh_up=1
    break
  fi
  launch_dead=0
  if [[ "$qemu_launch_pid" -ne 0 ]] && ! kill -0 "$qemu_launch_pid" 2>/dev/null; then
    launch_dead=1
  fi
  if [[ "$qemu_launch_pid" -eq 0 ]] && ! qnx_qemu_running; then
    launch_dead=1
  fi
  if [[ "$launch_dead" -eq 1 ]] && ! qnx_qemu_running; then
    echo "QEMU is not running. Last lines of serial.log:" >&2
    tail -n 50 "$QNX_TARGET_DIR/output/serial.log" >&2 || true
    if [[ -f "$QNX_TARGET_DIR/output/qemu.host.log" ]]; then
      echo "Last lines of qemu.host.log:" >&2
      tail -n 20 "$QNX_TARGET_DIR/output/qemu.host.log" >&2 || true
    fi
    qnx_die "QEMU exited before SSH came up. See $QNX_TARGET_DIR/output/serial.log"
  fi
  if [[ $((i % 5)) -eq 0 ]]; then
    echo "  still waiting ($((i * 2))s). Tail of serial.log:"
    tail -n 3 "$QNX_TARGET_DIR/output/serial.log" 2>/dev/null || true
  fi
  sleep 2
done
if [[ "$ssh_up" -ne 1 ]]; then
  echo "Last lines of serial.log:" >&2
  tail -n 50 "$QNX_TARGET_DIR/output/serial.log" >&2 || true
  qnx_die "Timed out waiting for SSH. See $QNX_TARGET_DIR/output/serial.log"
fi
echo "OK   SSH is accepting connections"

qnx_info "8/8 Deploy and run examples/hello-qnx"
"$ROOT/scripts/deploy-example.sh"

echo
qnx_info "Guest identity"
qnx_ssh 'uname -a; echo ---; pidin -F "%a %n"'

echo
echo "QNX SDP 8.0 guest is up."
echo "  ssh -p $QNX_SSH_PORT -i $QNX_SSH_KEY $QNX_SSH_USER@localhost"
echo "Stop it with:"
echo "  ./scripts/down.sh"
