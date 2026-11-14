# Codelab: QNX SDP 8.0 on a Mac

Build a QNX 8.0 system for QEMU, boot it on your Mac, and run a program you compiled with the QNX toolchain.

| | |
|---|---|
| **You need** | A Mac with Apple Silicon or Intel, Docker Desktop (or Colima on an older Intel macOS), and a QNX SDP 8.0 license. No QNX board. |
| **QNX** | SDP 8.0, installed in `~/qnx800`, plus the Linux 64-bit host tools. |
| **Target** | QEMU, `aarch64le`, machine `virt`. |
| **Toolchain** | `qcc -Vgcc_ntoaarch64le` (GCC 12.2.0) from the SDP's Linux host tools, inside Docker. The same compiler is `ntoaarch64-gcc`. |
| **Time** | About 30 minutes the first time, almost all of it the Docker image build. After that, `./scripts/up.sh` is about half a minute. |
| **Checked** | 2026-11-14, Apple Silicon MacBook Air, macOS 15.8.3, Homebrew QEMU 11.1.3, Docker image `qnx800`. Steps that were not repeated this session are marked. Not yet run on Intel hardware; the differences are in the README section [Intel Macs](../README.md#intel-macs). |

```text
Mac (Apple Silicon or Intel)
├── Homebrew qemu-system-aarch64          boots the guest
├── Docker container qnx-build            linux/amd64 (emulated on Apple Silicon, native on Intel)
│   └── QNX Linux host tools              qcc, mkqnximage
└── QEMU guest (TCG)                      QNX SDP 8.0, aarch64le, SSH on 127.0.0.1:2222
    └── /tmp/hello-qnx                    prints Hello QNX!
```

## Step 1: Get SDP 8.0 onto the Mac

**Not replayed this session.** The machine already had SDP 8.0 in `~/qnx800`.

1. Request the free non-commercial license at [qnx.com/getqnx](https://www.qnx.com/getqnx), accept it, and deploy it to your myQNX account.
2. Install QNX Software Center for macOS and install **QNX Software Development Platform 8.0** into `~/qnx800`.
3. In **Manage Installation → Available**, search for `Host Tools` and install **QNX SDP 8.0 Host Tools (Linux 64-bit)**.

SDP 8.0 does not include compilers for macOS. There is no `~/qnx800/host/darwin`. The VS Code QNX Toolkit errors about `host/darwin/x86_64` and `compilerPath .../qcc` come from that gap. This codelab does not use the toolkit, and it does not use Create Virtual Target.

**You should see** these paths on the Mac:

```text
~/qnx800/qnxsdp-env.sh
~/qnx800/host/linux/x86_64/usr/bin/qcc
```

Do not `source ~/qnx800/qnxsdp-env.sh` in a Mac terminal and expect `qcc` to run. On macOS that script points `QNX_HOST` at `host/win64`. The Linux tools run inside the container.

## Step 2: Install QEMU and start Docker

**Checked.**

```bash
brew install qemu
qemu-system-aarch64 --version
```

**You should see** a version line. On the test machine:

```text
QEMU emulator version 11.1.3
```

On an Intel Mac, `brew install qemu` may build from source (Homebrew Tier 3); `sudo port install qemu` from MacPorts is the alternative.

Open Docker Desktop and wait until it is running.

## Step 3: One command

**Checked.** From a clone of this repository that lives under your home directory (the container only mounts `$HOME`):

```bash
./scripts/up.sh
```

What that command does, in order:

1. Checks the Mac: Apple Silicon, Intel, or an Apple Silicon terminal under Rosetta (which it rejects); SDP, Linux `qcc`, QEMU and its architecture, Docker, `python3`, `ssh`, `scp`.
2. Creates the Docker image `qnx800` and the container `qnx-build` if they are missing. The Dockerfile comes from a clone of the upstream QNX macOS project in `~/.cache`, with Ubuntu 22.04 instead of 20.04. An existing container is not deleted.
3. Checks `startup-qemu-virt`, `devb-virtio`, and `sshd-auth`. If a QEMU package is missing and you exported `MYQNX_USER` and `MYQNX_PASSWORD`, it installs the package into `~/qnx800`. The password is not saved.
4. Creates `~/.ssh/id_ed25519` if you do not already have that key. An existing key is left as it is.
5. Builds the QEMU image with `mkqnximage` if `output/ifs.bin` is not there yet.
6. Starts QEMU on the Mac, detached, with the serial console in `~/qnxprojects/targets/qemu-qnx800-aarch64le/output/serial.log`.
7. Waits until SSH answers on port 2222: up to 180 seconds on Apple Silicon, 600 on Intel, or `QNX_BOOT_TIMEOUT`.
8. Compiles `examples/hello-qnx` in the container, copies it to the guest, and runs it.

The first Docker build can take about 30 minutes. The QNX image build after that is much shorter. On the test machine the command that stopped the old guest and ran `scripts/build-image.sh` finished in about 19 seconds, and the build log contained:

```text
Container build directory: /home/<user>/qnxprojects/targets/qemu-qnx800-aarch64le
Architecture: aarch64le
```

**You should see** the script end with the program and the guest identity. This is the output from the test machine after a clean image rebuild:

```text
Hello QNX!
sysname=QNX release=8.0.0 machine=QEMU_virt version=2026/06/05-16:21:14EDT

QNX qnx-a64 8.0.0 2026/06/05-16:21:14EDT QEMU_virt aarch64le
```

`pidin` on that guest lists `/proc/boot/procnto-smp-instr` as pid 1 and `devb-virtio` among the running processes. With the image already built, the whole `./scripts/up.sh` run took about 23 seconds.

Running `./scripts/up.sh` again does not rebuild the image and does not start a second QEMU. It compiles the example again and runs it on the guest that is already up.

## Step 4: Log in yourself

**Checked.**

```bash
ssh -p 2222 -i ~/.ssh/id_ed25519 root@localhost
```

**You should see** a QNX shell. Ask the guest who it is:

```sh
uname -a
/tmp/hello-qnx
```

**You should see:**

```text
QNX qnx-a64 8.0.0 2026/06/05-16:21:14EDT QEMU_virt aarch64le
Hello QNX!
sysname=QNX release=8.0.0 machine=QEMU_virt version=2026/06/05-16:21:14EDT
```

`qconn` is forwarded to port 8000 on the Mac. The serial log is `~/qnxprojects/targets/qemu-qnx800-aarch64le/output/serial.log`. A healthy boot ends with:

```text
---> Starting sshd
Startup complete
QNX qnx-a64 8.0.0 2026/06/05-16:21:14EDT QEMU_virt aarch64le
```

## Step 5: Change the program and run it again

**Checked** for the program as it is in the repository. Edit `examples/hello-qnx/hello-qnx.c`, keep the `Hello QNX!` line so the deploy script can recognise success, and run:

```bash
./scripts/deploy-example.sh
```

The compile happens in the container, after:

```bash
source /usr/local/qnx/env/bin/activate
source "$HOME/qnx800/qnxsdp-env.sh"
```

The link line is `qcc -Vgcc_ntoaarch64le -Wall -o hello-qnx hello-qnx.c`. On the Mac, `file examples/hello-qnx/hello-qnx` should report:

```text
ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /usr/lib/ldqnx-64.so.2
```

That interpreter path is the QNX dynamic linker. The binary is not a macOS executable. `scripts/deploy-example.sh` copies it to `/tmp/hello-qnx` on the guest and runs it. `/tmp` on this image is a symlink to `/data/var/tmp`.

## Step 6: Stop the guest

**Checked** earlier in the same session, before the rebuild (`./scripts/down.sh` stopped the QEMU pid and port 2222 was free afterwards).

```bash
./scripts/down.sh
```

Running it again when nothing is up prints that QEMU is not running and exits 0.

## When a step fails

| What you see | Where to look |
|---|---|
| `Unable to locate package python3.11` | [Pitfall 1](PITFALLS.md) |
| `Host file 'startup-qemu-virt' not available` | [Pitfall 2](PITFALLS.md) |
| `Unable to access /dev/hd0` | [Pitfall 3](PITFALLS.md) |
| `virt-4.2` is not a valid machine | [Pitfall 4](PITFALLS.md) |
| SSH worked, then `Connection refused` | [Pitfall 5](PITFALLS.md) |
| `sshd` starts but the connection resets | [Pitfall 6](PITFALLS.md) |
| `cd: /Users/...: No such file or directory` inside Docker | [Pitfall 7](PITFALLS.md) |
| `Permission denied (publickey)` | [Pitfall 8](PITFALLS.md) |
| `MISS native arm64 shell` | [Pitfall 10](PITFALLS.md) |
| `Timed out ... waiting for SSH` on an Intel Mac | [Pitfall 11](PITFALLS.md) |

Package install by hand, if you would rather not put a myQNX password in the environment: QNX Software Center → Manage Installation → Available → search `qemu` → install `com.qnx.qnx800.target.qemuvirt` and `com.qnx.qnx800.target.driver.virtio.devb`.
