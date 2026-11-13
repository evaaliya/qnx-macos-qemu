# Demo video (under 3 minutes)

Record this after the Docker image and the QNX packages are already installed. The first Docker build is about 30 minutes and does not fit in the video. On the test machine, with the image already built, `./scripts/up.sh` finished in about 23 seconds and the guest stayed up after the script returned.

Goal of the video: a person who has not seen the repo watches one command boot QNX SDP 8.0 on a Mac and run a program on that QNX system.

## Before you hit record

1. `./scripts/down.sh` so the recording starts from a stopped guest.
2. Open a terminal with a large font. `cd` to the clone.
3. Optional second terminal, same directory, for the SSH shot.
4. Do not show `~/.ssh`, QNX Software Center, or any password.

## Shot list

**0:00 – 0:15. Clean terminal, this Mac.**

```bash
clear
uname -m
sw_vers
qemu-system-aarch64 --version
```

Say: this is an Apple Silicon Mac. QNX SDP 8.0 has no macOS toolchain, so the build runs in Docker and the guest runs in QEMU.

**0:15 – 1:10. One command.**

```bash
./scripts/up.sh
```

Leave the scrollback visible. The lines that matter:

- `OK   Linux host tools`
- `Container build directory:` only appears if the image is built during the take. If the image already exists, the line is `image already built`.
- `Hello QNX!`
- `QNX qnx-a64 8.0.0 ... QEMU_virt aarch64le`
- `pidin` output with `/proc/boot/procnto-smp-instr` and `devb-virtio`

Say: that `Hello QNX!` was printed by a process on the QNX guest, not by the Mac. `uname` reports QNX 8.0.0, machine `QEMU_virt`, architecture `aarch64le`.

**1:10 – 2:00. Prove it is a shell on QNX.**

```bash
ssh -p 2222 -i ~/.ssh/id_ed25519 root@localhost
```

On the guest:

```sh
uname -a
pidin -F "%a %n"
/tmp/hello-qnx
```

Say: SSH is port 2222 on the Mac, forwarded to `sshd` in the guest. `pidin` is the QNX process list. Pid 1 is `procnto-smp-instr`.

Type `exit` to leave the guest. QEMU keeps running.

**2:00 – 2:35. Show the toolchain, briefly.**

```bash
sed -n '1,20p' examples/hello-qnx/hello-qnx.c
sed -n '1,20p' examples/hello-qnx/Makefile
```

Say: the source lives in this repo. `qcc -Vgcc_ntoaarch64le` is the SDP 8.0 compiler for `aarch64le`, and it runs inside the Linux container because SDP 8.0 does not ship Mac host tools. `./scripts/deploy-example.sh` is the compile, copy, and run step that `up.sh` already did.

**2:35 – 2:55. Stop, and the one-line close.**

```bash
./scripts/down.sh
```

Say: QNX SDP 8.0, QEMU `aarch64le`, on an Apple Silicon Mac, one command. Apache 2.0.

## If the guest is slow

TCG is the default accelerator. If the boot is still on `Waiting for SSH` at one minute, cut to the serial log instead of talking over the wait:

```bash
tail -n 20 ~/qnxprojects/targets/qemu-qnx800-aarch64le/output/serial.log
```

A finished boot contains `Startup complete` and `QNX qnx-a64 8.0.0`.

Do not set `QNX_QEMU_ACCEL=hvf` for the recording. On 2026-11-14 that accelerator stopped the guest in `gic_v3.c:966` before SSH came up. The default TCG boot is the one in the shot list.
