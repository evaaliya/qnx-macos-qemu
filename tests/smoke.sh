#!/usr/bin/env bash
# Checks a guest that ./scripts/up.sh has already booted. Exits 0 or 1.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

fail=0
bad() {
  printf 'FAIL %s\n' "$*" >&2
  fail=1
}

if ! qnx_qemu_running; then
  bad "QEMU is not running. Run ./scripts/up.sh first."
  exit 1
fi

if ! guest="$(qnx_ssh 'uname -a; echo ---; pidin -F "%a %n"; echo ---; /tmp/hello-qnx')"; then
  bad "ssh to the guest failed"
  exit 1
fi
printf '%s\n' "$guest"

printf '%s\n' "$guest" | grep -q 'Hello QNX!' || bad "missing Hello QNX!"
printf '%s\n' "$guest" | grep -q '8.0.0' || bad "missing QNX 8.0.0"
printf '%s\n' "$guest" | grep -q 'aarch64le' || bad "missing aarch64le"
printf '%s\n' "$guest" | grep -q 'procnto-smp-instr' || bad "missing procnto-smp-instr"

bin="$ROOT/examples/hello-qnx/hello-qnx"
if [[ ! -f "$bin" ]]; then
  bad "missing $bin"
else
  info="$(file "$bin")"
  printf '%s\n' "$info"
  printf '%s\n' "$info" | grep -q 'ARM aarch64' || bad "binary is not ARM aarch64"
  printf '%s\n' "$info" | grep -q 'ldqnx-64.so.2' || bad "interpreter is not /usr/lib/ldqnx-64.so.2"
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "smoke ok"
exit 0
