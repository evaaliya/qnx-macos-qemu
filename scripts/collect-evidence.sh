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
    'source /usr/local/qnx/env/bin/activate && source "$HOME/qnx800/qnxsdp-env.sh" && qcc -V 2>&1'
  echo
  echo "===== file examples/hello-qnx/hello-qnx ====="
  if [[ -f "$ROOT/examples/hello-qnx/hello-qnx" ]]; then
    file "$ROOT/examples/hello-qnx/hello-qnx"
  else
    echo "binary not built yet. ./scripts/up.sh builds it."
  fi
} >"$OUT/versions.txt"

qnx_info "Running ./scripts/up.sh"
# Keep going on failure so the log is still scrubbed below before anyone commits it.
up_rc=0
"$ROOT/scripts/up.sh" >"$OUT/up.log" 2>&1 || up_rc=$?

serial="$QNX_TARGET_DIR/output/serial.log"
if [[ -f "$serial" ]]; then
  tail -n 40 "$serial" >"$OUT/serial.log"
else
  echo "serial.log is missing" >"$OUT/serial.log"
fi

# The logs are committed. In every file under docs/evidence/:
#   $HOME -> ~
#   /home/<name> -> /home/<user>
#   the account name from id -un -> <user>
# $HOME is replaced first. Replacing the bare name first would turn
# /Users/<name> into /Users/<user>, and /Users/ would still be in the file.
user="$(id -un)"
while IFS= read -r f; do
  sed -i '' \
    -e "s|$HOME|~|g" \
    -e "s|/home/$user|/home/<user>|g" \
    -e "s|$user|<user>|g" \
    "$f"
done < <(find "$OUT" -type f)

if grep -E -n 'BEGIN (OPENSSH |RSA |EC )?PRIVATE|MYQNX_PASSWORD=.+' "$OUT"/* >/dev/null 2>&1; then
  qnx_die "docs/evidence contains a secret-shaped line"
fi
if grep -E -n '/(Users|home)/[A-Za-z0-9_-]+' "$OUT"/* >/dev/null 2>&1; then
  qnx_die "docs/evidence still contains a personal home path"
fi
if grep -F -n "/Users/" "$OUT"/* >/dev/null 2>&1; then
  qnx_die "docs/evidence still contains /Users/"
fi
if grep -F -n "$user" "$OUT"/* >/dev/null 2>&1; then
  qnx_die "docs/evidence still contains the current user name"
fi

if [[ "$up_rc" -ne 0 ]]; then
  qnx_die "./scripts/up.sh exited $up_rc. See $OUT/up.log"
fi

qnx_info "Wrote $OUT/versions.txt, $OUT/up.log, and $OUT/serial.log"
