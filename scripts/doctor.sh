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

note() {
  printf 'NOTE %s\n' "$*"
}

host_kind="$(qnx_host_kind)"
printf 'Host: %s %s (%s, %s)\n' "$(sw_vers -productName)" "$(sw_vers -productVersion)" "$(uname -m)" "$host_kind"

case "$host_kind" in
  apple-silicon)
    echo "OK   Apple Silicon (arm64). This is the path the logs in docs/evidence were captured on."
    ;;
  apple-silicon-rosetta)
    bad "native arm64 shell. This terminal runs as x86_64 under Rosetta on an Apple Silicon Mac."
    echo "     x86_64 QEMU and Homebrew under Rosetta are slower and were not tested."
    echo "     Open a native terminal (Get Info on Terminal.app: untick \"Open using Rosetta\"),"
    echo "     or run: arch -arm64 /bin/zsh -l"
    ;;
  intel)
    echo "OK   Intel Mac (x86_64). Supported, with differences:"
    echo "     - The guest runs under TCG only. HVF cannot run an aarch64 guest on x86_64."
    echo "     - Boot is slower; up.sh waits up to $(qnx_default_boot_timeout)s for SSH (QNX_BOOT_TIMEOUT)."
    echo "     - The qnx800 Docker image is linux/amd64 and runs natively, without emulation."
    echo "     - The logs in docs/evidence come from Apple Silicon. See README, \"Intel Macs\"."
    if [[ "${QNX_QEMU_ACCEL:-tcg}" == "hvf" ]]; then
      bad "QNX_QEMU_ACCEL=hvf cannot work on Intel. Unset it."
    fi
    ;;
esac

if [[ "$host_kind" == "intel" ]]; then
  mem_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))
  if [[ "$mem_gb" -lt 8 ]]; then
    note "$mem_gb GB RAM. Docker Desktop and a 1 GB guest together are tight below 8 GB."
  fi
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

if [[ "$host_kind" == "intel" ]]; then
  qemu_hint="Install on the Mac: brew install qemu (Homebrew on Intel is Tier 3 and may build it from source), or: sudo port install qemu"
  docker_hint="Install Docker Desktop for Mac (Intel chip) and start it. On a macOS too old for Docker Desktop, see README, \"Intel Macs\" (Colima)."
else
  qemu_hint="Install on the Mac: brew install qemu"
  docker_hint="Install Docker Desktop for Mac (Apple Silicon) and start it."
fi
check_cmd qemu-system-aarch64 "$qemu_hint"
check_cmd docker "$docker_hint"

# A QEMU binary built for the other architecture still runs (Rosetta), but slowly.
if qemu_bin="$(command -v qemu-system-aarch64 2>/dev/null)"; then
  qemu_file="$(file -L "$qemu_bin" 2>/dev/null || true)"
  case "$host_kind:$qemu_file" in
    apple-silicon*:*arm64*|intel:*x86_64*) ;;
    apple-silicon*:*x86_64*)
      note "$qemu_bin is an x86_64 build running under Rosetta. Install the arm64 one: /opt/homebrew/bin/brew install qemu"
      ;;
    *)
      note "could not tell which architecture $qemu_bin is built for."
      ;;
  esac
fi
check_cmd python3 "python3 detaches QEMU so it keeps running after ./scripts/up.sh returns."
check_cmd ssh "ssh is part of macOS. Reinstall the Command Line Tools if it is missing."
check_cmd scp "scp is part of macOS. Reinstall the Command Line Tools if it is missing."

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    echo "OK   Docker daemon ($(docker info --format '{{.Architecture}}' 2>/dev/null || echo unknown))"
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
