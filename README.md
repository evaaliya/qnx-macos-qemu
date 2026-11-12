# QNX on Apple Silicon (macOS + Docker + QEMU)

Scripts and fixes to **build** a QNX SDP 8.0 `aarch64le` QEMU image inside a Linux Docker container and **run** it with Homebrew QEMU on an Apple Silicon Mac.

This documents pitfalls that block beginners on macOS (missing SDP packages, QEMU `virt-4.2` removal, `sshd-auth` omitted from stock `mkqnximage`).

## Versions / toolchain

| Item | Value used here |
|------|-----------------|
| Host | macOS (Apple Silicon) |
| QNX | SDP **8.0** (`~/qnx800`) |
| Target arch | **aarch64le** |
| Image tool | `mkqnximage --type=qemu` (Linux host tools in Docker) |
| Emulator | Homebrew **qemu-system-aarch64** (tested with QEMU 11; use `-machine virt`) |
| Cross/build container | Docker image/container named `qnx-build` (see [QNX macOS Docker guide](https://qnx.software/en/blog/2026/how-to-use-macos-to-develop-for-qnx)) |

## Prerequisites

1. QNX license + SDP 8.0 + **Linux Host Tools** via QNX Software Center.
2. Docker Desktop with a working `qnx-build` container (HOME mounted).
3. On the Mac: `brew install qemu`.
4. In QSC, install (easy to miss):
   - `com.qnx.qnx800.target.qemuvirt` — Startup (`startup-qemu-virt`)
   - `com.qnx.qnx800.target.driver.virtio.devb` — Block (`devb-virtio`)

Check:

```bash
./scripts/check-prereqs.sh
```

## Build the image (inside Docker)

```bash
./scripts/build-image.sh
```

This copies the `sshd-auth` snippets + `run.sh` into:

`~/qnxprojects/targets/qemu-qnx800-aarch64le`

and runs `mkqnximage --type=qemu --arch=aarch64le --hostname=qnx-a64 --clean --build` in `qnx-build`.

## Run the guest (on the Mac host — not in Docker)

```bash
cd ~/qnxprojects/targets/qemu-qnx800-aarch64le
./run.sh
```

SSH (default forward):

```bash
ssh -p 2222 -i ~/.ssh/id_ed25519 root@localhost
```

`qconn` is forwarded to host port **8000**.

Stop:

```bash
kill "$(cat output/qemu.pid)"
```

## What this repo fixes

1. **`startup-qemu-virt` missing** → install `qemuvirt` package; `check-prereqs.sh` tells you.
2. **`devb-virtio` missing** → install Block virtio package or boot dies with `Unable to access /dev/hd0`.
3. **QEMU 11 dropped `virt-4.2`** → `run.sh` uses `-machine virt`.
4. **Background QEMU dying** → serial goes to `output/serial.log` instead of a TTY.
5. **`sshd-auth` not packaged by stock mkqnximage** → `local/snippets/system_files.custom` + IFS link in `ifs_files.custom`.

## Layout

```
scripts/check-prereqs.sh   # package / tool gate
scripts/build-image.sh     # Docker mkqnximage wrapper
qemu-aarch64le/run.sh      # host QEMU launcher
qemu-aarch64le/local/snippets/
```

## Security

Do **not** commit filled connection files with passwords. Prefer SSH keys. Built disks under `output/` are gitignored.

## License

Apache License 2.0 — see `LICENSE`.
