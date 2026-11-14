# Agents working in this repository

This repo boots QNX SDP 8.0 on a Mac. QNX SDP 8.0 does not support macOS or ARM hosts ([Quickstart Guide, Installation](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.qnxsdp.quickstart/topic/install_host.html)); Docker runs the Linux host tools, and Homebrew QEMU runs the `aarch64le` guest under TCG. Apple Silicon is the tested path. Intel has not been checked, because there is no Intel Mac; do not claim it has been run. Use the scripts. Do not invent a second launch path.

## First-time setup

Follow [README.md](README.md) from Quick start through `./scripts/up.sh`. README steps 6 and 7 are the myQNX account, the license, and QNX Software Center. Tell the person to do those steps themselves. Do not click them and do not restate them. A program of your own is [docs/TUTORIAL.md](docs/TUTORIAL.md).

After any command, if a script prints a line that starts with `HUMAN ACTION:`, quote that line to the person verbatim and wait. Do not ask for the myQNX password in chat, and do not write it into a file, a commit, or a log. `MYQNX_USER` and `MYQNX_PASSWORD` are read only when the person has already exported them in their own terminal. Do not pass `-cleanInstall`. Package ids and the command-line flags are in README step 8.

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
| Homebrew git and QEMU, start Docker, then bring-up | `./scripts/bootstrap.sh` |
| Guest smoke test | `./tests/smoke.sh` |
| Stop QEMU | `./scripts/down.sh` |
| Host checks only | `./scripts/doctor.sh` |
| Docker image and container | `./scripts/setup-docker.sh` |
| QNX packages | `./scripts/check-prereqs.sh` |
| SSH key, without overwriting one | `./scripts/ensure-ssh-key.sh` |
| Rebuild the QNX image | `./scripts/down.sh` then `./scripts/build-image.sh` |
| Compile and run the example | `./scripts/deploy-example.sh` (calls `run-on-qnx.sh`) |
| Compile and run any project under `$HOME` | `./scripts/run-on-qnx.sh PATH` |
| New project in `~/qnxprojects` | `./scripts/new-project.sh NAME` |

`./scripts/up.sh` is idempotent: a second run leaves an existing image and a running QEMU in place and deploys the example again. `./scripts/setup-docker.sh` does not delete `qnx-build`. `./scripts/build-image.sh` refuses to run while QEMU has the disk open.

The guest keeps running after `up.sh` returns. Stop it with `down.sh`, which reads `~/qnxprojects/targets/qemu-qnx800-aarch64le/output/qemu.pid` and will not kill a pid that is not `qemu-system-aarch64`.

## How a compile is supposed to happen

Use `./scripts/run-on-qnx.sh PATH`. The steps and the guest commands (`ssh`, `slog2info`, `pidin`) are in [docs/TUTORIAL.md](docs/TUTORIAL.md). The repository and the project both have to sit under `$HOME`, because the container mounts that directory and has no `/Users` tree. Do not `source ~/qnx800/qnxsdp-env.sh` on the Mac and compile there: on macOS that script selects `host/win64`.

## Rules that are easy to violate

- Do not commit `output/`, `*.vmdk`, `ifs.bin`, SSH private keys, `.env` files, or myQNX passwords. Credentials for `check-prereqs.sh` come from `MYQNX_USER` and `MYQNX_PASSWORD` and must not be written into the repo.
- Do not edit `~/qnx800`, `~/qnxprojects`, `~/docker-mac`, the `qnx-build` container, or the `qnx800` image by hand. The scripts are the supported way to rebuild the guest image.
- Do not copy files from `gitlab.com/qnx/projects/docker-mac` into this repo. `setup-docker.sh` clones that project into `~/.cache/qnx-macos-qemu/docker-mac` and patches `ubuntu:20.04` to `ubuntu:22.04` there.
- Do not pass `-machine virt-4.2`. QEMU 11 does not have it. `run.sh` uses `-machine virt`.
- Detect the host with `qnx_host_kind` in `scripts/lib.sh`, not `uname -m`. Under Rosetta `uname -m` prints `x86_64` on Apple Silicon.
- HVF never works on Intel: the guest is aarch64. `run.sh` and `doctor.sh` refuse it there.
- Do not change the default accelerator to HVF. On 2026-11-14 `QNX_QEMU_ACCEL=hvf` stopped the guest in `gic_v3.c:966` and SSH never came up. The default is `-accel tcg -cpu cortex-a57`. See [docs/PITFALLS.md](docs/PITFALLS.md).
- Do not create the SSH key after `mkqnximage`. The public key is copied into the image at build time.
- Read [docs/PITFALLS.md](docs/PITFALLS.md) before debugging a boot failure. The serial log is `~/qnxprojects/targets/qemu-qnx800-aarch64le/output/serial.log`.

## A new guest program

[docs/TUTORIAL.md](docs/TUTORIAL.md). `./scripts/new-project.sh NAME` writes `~/qnxprojects/NAME`. `./scripts/run-on-qnx.sh` builds it. `./scripts/deploy-example.sh` is that script pointed at `examples/hello-qnx`.
