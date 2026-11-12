#!/usr/bin/env bash
# Fail fast with the package names novices miss on Apple Silicon + Docker QNX builds.
set -euo pipefail

SDP="${QNX_SDP:-$HOME/qnx800}"
ARCH="${QNX_IMAGE_ARCH:-aarch64le}"
ok=1

need_file() {
  local path="$1" pkg="$2" hint="$3"
  if [[ -e "$path" ]]; then
    echo "OK   $path"
  else
    echo "MISS $path"
    echo "     Install from QNX Software Center: $pkg"
    echo "     ($hint)"
    ok=0
  fi
}

echo "SDP: $SDP"
need_file \
  "$SDP/target/qnx/$ARCH/boot/sys/startup-qemu-virt" \
  "com.qnx.qnx800.target.qemuvirt" \
  "QEMU Virtualization Drivers (Startup)"

need_file \
  "$SDP/target/qnx/$ARCH/sbin/devb-virtio" \
  "com.qnx.qnx800.target.driver.virtio.devb" \
  "Virtualization Drivers (Block)"

need_file \
  "$SDP/target/qnx/$ARCH/usr/libexec/sshd-auth" \
  "OpenSSH components in SDP (usually already present)" \
  "Required helper; mkqnximage stock SSH section may omit packaging it — see local/snippets"

if ! command -v qemu-system-aarch64 >/dev/null; then
  echo "MISS qemu-system-aarch64 (host). Install: brew install qemu"
  ok=0
else
  echo "OK   qemu-system-aarch64 ($(qemu-system-aarch64 --version | head -1))"
fi

if ! docker info >/dev/null 2>&1; then
  echo "MISS Docker daemon (needed for mkqnximage via qnx-build container)"
  ok=0
else
  echo "OK   Docker"
fi

if [[ "$ok" -ne 1 ]]; then
  echo
  echo "Fix the MISS lines above, then re-run: ./scripts/check-prereqs.sh"
  exit 1
fi

echo
echo "Prereqs look good."
