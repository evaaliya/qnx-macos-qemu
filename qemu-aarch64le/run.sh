#!/usr/bin/env bash
# Run the QNX aarch64le image with Homebrew QEMU on the Mac.
# Default accelerator is TCG.
# QNX_QEMU_ACCEL=hvf was booted on this tree on 2026-11-14 and stopped in gic_v3.c:966.
set -euo pipefail

if [[ -n "${TARGET_DIR:-}" ]]; then
  cd "$TARGET_DIR"
else
  cd "$(dirname "$0")"
fi

if [[ ! -f output/ifs.bin || ! -f output/disk-qemu.vmdk ]]; then
  echo "error: output/ifs.bin or output/disk-qemu.vmdk is missing in $(pwd)" >&2
  echo "Build the image first: ./scripts/build-image.sh" >&2
  exit 1
fi

mkdir -p output

ACCEL="${QNX_QEMU_ACCEL:-tcg}"
CPU="cortex-a57"
case "$ACCEL" in
  tcg) ;;
  hvf)
    CPU="host"
    echo "warning: QNX_QEMU_ACCEL=hvf was checked on 2026-11-14. The guest stopped in gic_v3.c:966 and SSH did not come up. The default is tcg." >&2
    ;;
  *)
    echo "error: QNX_QEMU_ACCEL must be tcg (default) or hvf. Got: $ACCEL" >&2
    exit 1
    ;;
esac

# QEMU 11 dropped the virt-4.2 machine. Serial goes to a file so the process
# survives when it is not attached to a terminal.
exec qemu-system-aarch64 \
  -machine virt \
  -cpu "$CPU" \
  -smp 2 \
  -accel "$ACCEL" \
  -m 1G \
  -drive file=output/disk-qemu.vmdk,if=none,id=drv0 \
  -device virtio-blk-device,drive=drv0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8000-:8000 \
  -device virtio-net-device,netdev=net0,mac=52:54:00:b4:ae:64 \
  -pidfile output/qemu.pid \
  -nographic \
  -serial file:output/serial.log \
  -monitor none \
  -kernel output/ifs.bin \
  -object rng-random,filename=/dev/urandom,id=rng0 \
  -device virtio-rng-device,rng=rng0
