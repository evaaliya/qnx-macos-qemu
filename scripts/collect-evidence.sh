#!/usr/bin/env bash
# Refresh docs/evidence/ from this machine. No passwords, tokens, or private keys.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

OUT="$ROOT/docs/evidence"
mkdir -p "$OUT"

{
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "===== sw_vers ====="
  sw_vers
  uname -m
  echo
  echo "===== qemu-system-aarch64 --version ====="
  qemu-system-aarch64 --version
  echo
  echo "===== docker version ====="
  docker version
  echo
  echo "===== qcc -V ====="
  docker exec "$QNX_BUILD_CONTAINER" bash -lc \
    'source /usr/local/qnx/env/bin/activate && source "$HOME/qnx800/qnxsdp-env.sh" && qcc -V'
  echo
  echo "===== file examples/hello-qnx/hello-qnx ====="
  if [[ -f "$ROOT/examples/hello-qnx/hello-qnx" ]]; then
    file "$ROOT/examples/hello-qnx/hello-qnx"
  else
    echo "binary not built yet. ./scripts/up.sh builds it."
  fi
} >"$OUT/versions.txt"

qnx_info "Running ./scripts/up.sh"
"$ROOT/scripts/up.sh" >"$OUT/up.log" 2>&1

serial="$QNX_TARGET_DIR/output/serial.log"
if [[ -f "$serial" ]]; then
  tail -n 40 "$serial" >"$OUT/serial.log"
else
  echo "serial.log is missing" >"$OUT/serial.log"
fi

if grep -E -n 'BEGIN (OPENSSH |RSA |EC )?PRIVATE|MYQNX_PASSWORD=.+' "$OUT"/* >/dev/null 2>&1; then
  qnx_die "docs/evidence contains a secret-shaped line"
fi

qnx_info "Wrote $OUT/versions.txt, $OUT/up.log, and $OUT/serial.log"
