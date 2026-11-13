#!/usr/bin/env bash
# Host checks. Does not install software and does not need the guest to be running.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

ok=1
bad() {
  printf 'MISS %s\n' "$*"
  ok=0
}

printf 'Host: %s %s (%s)\n' "$(sw_vers -productName)" "$(sw_vers -productVersion)" "$(uname -m)"

if [[ "$(uname -m)" == "arm64" ]]; then
  echo "OK   Apple Silicon (arm64)"
else
  bad "Apple Silicon (arm64). This machine is $(uname -m)."
fi

if [[ -f "$QNX_SDP/qnxsdp-env.sh" ]]; then
  echo "OK   $QNX_SDP/qnxsdp-env.sh"
else
  bad "$QNX_SDP/qnxsdp-env.sh"
  echo "     Install QNX SDP 8.0 with QNX Software Center into $QNX_SDP."
fi

qcc_host="$QNX_SDP/host/linux/x86_64/usr/bin/qcc"
if [[ -e "$qcc_host" ]]; then
  echo "OK   Linux host tools ($qcc_host)"
else
  bad "$qcc_host"
  echo "     SDP 8.0 has no macOS host tools (no host/darwin)."
  echo "     In QNX Software Center: Manage Installation -> Available, search \"Host Tools\"."
  echo "     Install QNX SDP 8.0 Host Tools (Linux 64-bit). Builds run inside Docker."
fi

check_cmd() {
  local cmd="$1"
  local hint="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK   $cmd ($(command -v "$cmd"))"
  else
    bad "$cmd"
    echo "     $hint"
  fi
}

check_cmd qemu-system-aarch64 "Install on the Mac: brew install qemu"
check_cmd docker "Install Docker Desktop for Mac and start it."
check_cmd python3 "python3 detaches QEMU so it keeps running after ./scripts/up.sh returns."
check_cmd ssh "ssh is part of macOS. Reinstall the Command Line Tools if it is missing."
check_cmd scp "scp is part of macOS. Reinstall the Command Line Tools if it is missing."

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    echo "OK   Docker daemon"
  else
    bad "Docker daemon"
    echo "     Start Docker Desktop, wait until it is running, then re-run ./scripts/doctor.sh"
  fi
fi

if [[ "$ok" -ne 1 ]]; then
  echo
  echo "Fix the MISS lines above, then re-run: ./scripts/doctor.sh"
  exit 1
fi

echo
echo "Host looks ready."
