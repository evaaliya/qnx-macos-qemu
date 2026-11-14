---
name: qnx-macos-qemu
description: Build and boot QNX SDP 8.0 for QEMU aarch64le on a Mac (Apple Silicon or Intel) with the scripts in this repository. Use when compiling a QNX guest program, running mkqnximage, or debugging a QEMU boot from this tree.
---

# QNX SDP 8.0 on a Mac

Use the scripts in this repository. Do not invent a second launch path, and do not edit `~/qnx800`, `~/docker-mac`, the `qnx-build` container, or the `qnx800` image by hand.

## Success

`./scripts/up.sh` exits 0. The guest prints `Hello QNX!`, `uname -a` contains `QNX`, `8.0.0`, and `aarch64le`, and `pidin` lists `/proc/boot/procnto-smp-instr`.

A QNX binary is ELF `ARM aarch64` with interpreter `/usr/lib/ldqnx-64.so.2`.

## Commands

| Goal | Command |
|------|---------|
| Bring-up | `./scripts/up.sh` |
| Stop | `./scripts/down.sh` |
| Compile and run the example | `./scripts/deploy-example.sh` |
| Guest checks | `./tests/smoke.sh` |
| Refresh `docs/evidence/` | `./scripts/collect-evidence.sh` |

Host kind comes from `qnx_host_kind` in `scripts/lib.sh`: `apple-silicon` (tested), `intel` (TCG only, longer `QNX_BOOT_TIMEOUT`, untested on hardware), or `apple-silicon-rosetta` (rejected by `doctor.sh`).

The repository must live under `$HOME`. Inside the container that path is `/home/<user>/...`, not `/Users/...`.

Compile only after this, inside `qnx-build`:

```bash
source /usr/local/qnx/env/bin/activate
source "$HOME/qnx800/qnxsdp-env.sh"
qcc -Vgcc_ntoaarch64le -o hello-qnx hello-qnx.c
```

## Do not

- Commit `output/`, `*.vmdk`, `ifs.bin`, SSH private keys, `.env`, or myQNX passwords.
- Pass `-machine virt-4.2`. QEMU 11 uses `-machine virt`.
- Set `QNX_QEMU_ACCEL=hvf` as the default. On 2026-11-14 it stopped in `gic_v3.c:966` and SSH never came up. Default is `-accel tcg -cpu cortex-a57`.
- Create the SSH key after `mkqnximage`. `scripts/ensure-ssh-key.sh` runs first.
- Copy files from `gitlab.com/qnx/projects/docker-mac` into this repo. `scripts/setup-docker.sh` clones that project into the cache and switches Ubuntu 20.04 to 22.04 there.

Read [AGENTS.md](../../../AGENTS.md) and [docs/PITFALLS.md](../../../docs/PITFALLS.md) before changing the boot path.
