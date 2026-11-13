#!/usr/bin/env bash
# Stop the QEMU process recorded in the target image's output/qemu.pid.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

pidfile="$QNX_TARGET_DIR/output/qemu.pid"
pid="$(qnx_qemu_pid || true)"
if [[ -z "$pid" ]]; then
  echo "QEMU is not running (no pidfile at $pidfile)."
  exit 0
fi

if ! kill -0 "$pid" 2>/dev/null; then
  echo "Removing stale pidfile (pid $pid is not running)."
  rm -f "$pidfile"
  exit 0
fi

cmd="$(qnx_qemu_command "$pid")"
case "$cmd" in
  *qemu-system-aarch64*) ;;
  *)
    qnx_die "Refusing to kill pid $pid from $pidfile because it is not qemu-system-aarch64. Command: $cmd"
    ;;
esac

qnx_info "Stopping QEMU pid $pid"
kill "$pid" 2>/dev/null || true

i=0
while kill -0 "$pid" 2>/dev/null; do
  i=$((i + 1))
  if [[ "$i" -ge 20 ]]; then
    echo "QEMU did not exit after SIGTERM; sending SIGKILL."
    kill -9 "$pid" 2>/dev/null || true
    break
  fi
  sleep 0.5
done

if kill -0 "$pid" 2>/dev/null; then
  qnx_die "QEMU pid $pid is still running."
fi
rm -f "$pidfile"
echo "QEMU stopped."
