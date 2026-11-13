# Agents working in this repository

This repo boots QNX SDP 8.0 on a Mac with Apple Silicon: Docker runs the Linux host tools, Homebrew QEMU runs the `aarch64le` guest. Use the scripts. Do not invent a second launch path.

## What “it works” means

`./scripts/up.sh` exits 0, and the guest output contains all of the following:

- `Hello QNX!`
- `QNX` and `8.0.0` and `aarch64le` from `uname -a`
- a `pidin` line for `/proc/boot/procnto-smp-instr`

A binary is a QNX binary only if `file` reports `ARM aarch64` and interpreter `/usr/lib/ldqnx-64.so.2`. A Mach-O file is a Mac binary and is the wrong result.

Checked output from 2026-11-14:

```text
Hello QNX!
sysname=QNX release=8.0.0 machine=QEMU_virt version=2026/06/05-16:21:14EDT
QNX qnx-a64 8.0.0 2026/06/05-16:21:14EDT QEMU_virt aarch64le
```

## Commands

| Goal | Command |
|------|---------|
| Full bring-up | `./scripts/up.sh` |
| Stop QEMU | `./scripts/down.sh` |
| Host checks only | `./scripts/doctor.sh` |
| Docker image and container | `./scripts/setup-docker.sh` |
| QNX packages | `./scripts/check-prereqs.sh` |
| SSH key, without overwriting one | `./scripts/ensure-ssh-key.sh` |
| Rebuild the QNX image | `./scripts/down.sh` then `./scripts/build-image.sh` |
| Compile and run the example | `./scripts/deploy-example.sh` |

`./scripts/up.sh` is idempotent: a second run leaves an existing image and a running QEMU in place and deploys the example again. `./scripts/setup-docker.sh` does not delete `qnx-build`. `./scripts/build-image.sh` refuses to run while QEMU has the disk open.

The guest keeps running after `up.sh` returns. Stop it with `down.sh`, which reads `~/qnxprojects/targets/qemu-qnx800-aarch64le/output/qemu.pid` and will not kill a pid that is not `qemu-system-aarch64`.

## How a compile is supposed to happen

The repository must be cloned under `$HOME`. The container mounts that directory at `/home/<user>` and has no `/Users` tree.

Inside `qnx-build`:

```bash
source /usr/local/qnx/env/bin/activate
source "$HOME/qnx800/qnxsdp-env.sh"
qcc -Vgcc_ntoaarch64le -o hello-qnx hello-qnx.c
```

`qcc -V` on the test machine listed `12.2.0,gcc_ntoaarch64le`. Do not `source ~/qnx800/qnxsdp-env.sh` on the Mac and compile there: on macOS that script selects `host/win64`.

SSH from the Mac, not from the container:

```bash
ssh -p 2222 -i ~/.ssh/id_ed25519 root@localhost
```

## Rules that are easy to violate

- Do not commit `output/`, `*.vmdk`, `ifs.bin`, SSH private keys, `.env` files, or myQNX passwords. Credentials for `check-prereqs.sh` come from `MYQNX_USER` and `MYQNX_PASSWORD` and must not be written into the repo.
- Do not edit `~/qnx800`, `~/qnxprojects`, `~/docker-mac`, the `qnx-build` container, or the `qnx800` image by hand. The scripts are the supported way to rebuild the guest image.
- Do not copy files from `gitlab.com/qnx/projects/docker-mac` into this repo. `setup-docker.sh` clones that project into `~/.cache/qnx-macos-qemu/docker-mac` and patches `ubuntu:20.04` to `ubuntu:22.04` there.
- Do not pass `-machine virt-4.2`. QEMU 11 does not have it. `run.sh` uses `-machine virt`.
- Do not change the default accelerator to HVF. On 2026-11-14 `QNX_QEMU_ACCEL=hvf` stopped the guest in `gic_v3.c:966` and SSH never came up. The default is `-accel tcg -cpu cortex-a57`. See [docs/PITFALLS.md](docs/PITFALLS.md).
- Do not create the SSH key after `mkqnximage`. The public key is copied into the image at build time.
- Read [docs/PITFALLS.md](docs/PITFALLS.md) before debugging a boot failure. The serial log is `~/qnxprojects/targets/qemu-qnx800-aarch64le/output/serial.log`.

## A new guest program

Put it under `examples/`, build it with `qcc -Vgcc_ntoaarch64le` inside the container, copy it with `scp -P 2222`, and run it over SSH. `scripts/deploy-example.sh` is the pattern. Add the built binary to `.gitignore`.
