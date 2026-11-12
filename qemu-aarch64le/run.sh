#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# QEMU 11 no longer provides virt-4.2; use current virt.
# Keep guest alive when launched without a TTY by logging serial to a file.
exec qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a57 \
    -smp 2 \
    -accel tcg \
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
