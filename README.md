# QNX SDP 8.0 on an Apple Silicon Mac

This guide gets a new Apple Silicon Mac from an empty terminal to a QNX SDP 8.0 guest running under QEMU. One command does the boot, once the tools below are installed:

```bash
./scripts/up.sh
```

Any Mac whose `uname -m` prints `arm64` is the machine this path is for: MacBook Air, MacBook Pro, Mac mini, iMac, Mac Studio, Mac Pro. The scripts check `arm64`. They do not check the product name. The command output in this file was captured on 2026-11-14 on a MacBook Air, macOS 15.8.3 (`24H314`).

Stop the guest with `./scripts/down.sh`.

## 1. Install Homebrew

Install Homebrew from [brew.sh](https://brew.sh), then open a new terminal.

**You should see** a version line. On this machine `brew --version` printed:

```text
Homebrew 7.0.13
```

## 2. Install Git

```bash
brew install git
git --version
```

If Git is already installed, `brew install git` is optional.

**You should see** a version line. On this machine `which git` was `/usr/bin/git` and `git --version` printed:

```text
git version 2.50.1 (Apple Git-155)
```

## 3. Install Docker Desktop and start it

Install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) (Apple Silicon) and wait until the engine is running.

**You should see** a client and a server. On this machine `docker version` printed:

```text
Client:
 Version:           29.9.3
 OS/Arch:           darwin/arm64

Server: Docker Desktop 4.99.0 (245822)
 Engine:
  Version:          29.9.3
  OS/Arch:          linux/arm64
```

The full `docker version` listing is in [docs/evidence/versions.txt](docs/evidence/versions.txt).

## 4. Install QEMU

```bash
brew install qemu
qemu-system-aarch64 --version
```

**You should see:**

```text
QEMU emulator version 11.1.3
Copyright (c) 2003-2026 Fabrice Bellard and the QEMU Project developers
```

`brew list --versions qemu` printed `qemu 11.1.3`.

## 5. Install VS Code (optional)

Install [Visual Studio Code](https://code.visualstudio.com/) if you want an editor. This repository does not require it, and it does not use the QNX Toolkit's Create Virtual Target flow. SDP 8.0 has no `~/qnx800/host/darwin`, so the toolkit's `host/darwin/x86_64 is not a directory` message is expected.

**You should see** the app on disk. On this machine:

```text
defaults read "/Applications/Visual Studio Code.app/Contents/Info" CFBundleShortVersionString
1.103.2
```

`code` was not on `PATH` in the terminal that recorded this. The app itself was installed.

## 6. Create a myQNX account and get the free license

1. Open [qnx.com/getqnx](https://www.qnx.com/getqnx).
2. Create a myQNX account.
3. Request the free non-commercial QNX SDP 8.0 license and deploy it to that account.

**You should see** the license attached to your myQNX account, and QNX Software Center able to sign in with it. This checkout did not re-run the website wizard. The installed result is the next step.

## 7. Install QNX Software Center

Install QNX Software Center for macOS from the myQNX account and open it.

**You should see** the application. On this machine:

```text
defaults read "/Applications/QNX Software Center.app/Contents/Info" CFBundleShortVersionString
1.7.0
```

The command-line tool is on disk at:

```text
/Applications/QNX Software Center.app/Contents/Eclipse/qnxsoftwarecenter_clt
```

`./scripts/check-prereqs.sh` calls that tool only when a required package is missing and both `MYQNX_USER` and `MYQNX_PASSWORD` are set. Those variables are not stored. A live `-installPackage` run is not part of the captured logs in this repository.

## 8. Install SDP 8.0 and the Linux host tools

In QNX Software Center:

1. Add an installation. Choose **QNX Software Development Platform 8.0** and install it into `~/qnx800`.
2. Open **Manage Installation → Available**, search for `Host Tools`, and install **QNX SDP 8.0 Host Tools (Linux 64-bit)**.

There is no macOS compiler in SDP 8.0. Builds run inside Docker, where those Linux tools are on `PATH`.

**You should see** these files:

```text
~/qnx800/qnxsdp-env.sh
~/qnx800/host/linux/x86_64/usr/bin/qcc
```

On this machine both were present (`qnxsdp-env.sh` is 1577 bytes, `qcc` is the Linux ELF at that path). Inside the `qnx-build` container, `qcc -V` printed:

```text
QNX_HOST=/home/<user>/qnx800/host/linux/x86_64
cc: targets available in /home/<user>/qnx800/host/linux/x86_64/etc/qcc:
	12.2.0,gcc_ntox86_64	(default)
	12.2.0,gcc_ntoaarch64le
	12.2.0,gcc_ntox86_64_cxx
	12.2.0,gcc_ntox86_64_gpp
	12.2.0,gcc_ntoaarch64le_cxx
	12.2.0,gcc_ntoaarch64le_gpp
```

The guest compiler used by this repo is `qcc -Vgcc_ntoaarch64le`. The same compiler is `ntoaarch64-gcc`. Do not `source ~/qnx800/qnxsdp-env.sh` in a Mac terminal and compile there: on macOS that script selects `host/win64`.

Two more packages are required before the image will build. Search Available for `qemu` and install:

- `com.qnx.qnx800.target.qemuvirt` (QEMU Virtualization Drivers, Startup)
- `com.qnx.qnx800.target.driver.virtio.devb` (Virtualization Drivers, Block)

**You should see** the files `./scripts/check-prereqs.sh` checks. On this machine:

```text
OK   ~/qnx800/target/qnx/aarch64le/boot/sys/startup-qemu-virt
OK   ~/qnx800/target/qnx/aarch64le/sbin/devb-virtio
OK   ~/qnx800/target/qnx/aarch64le/usr/libexec/sshd-auth
```

If you want the script to install a missing package for you:

```bash
export MYQNX_USER='you@example.com'
export MYQNX_PASSWORD='your-myqnx-password'
./scripts/check-prereqs.sh
```

The password is an argument to that one process. It is not written into the repo.

## 9. Clone this repository into your home folder

The Docker container bind-mounts your home directory. A clone outside `$HOME` is invisible to the container.

```bash
cd "$HOME"
git clone https://github.com/evaaliya/qnx-macos-qemu.git
cd qnx-macos-qemu
pwd
```

**You should see** a path under your home directory. On this machine that path is:

```text
~/qnx-macos-qemu
```

## 10. Boot QNX and run the example

```bash
./scripts/up.sh
```

The first time, building the Docker image `qnx800` can take about 30 minutes. `scripts/setup-docker.sh` clones [gitlab.com/qnx/projects/docker-mac](https://gitlab.com/qnx/projects/docker-mac) into `~/.cache/qnx-macos-qemu/docker-mac` and changes `FROM ubuntu:20.04` to `FROM ubuntu:22.04` before that build. Later runs reuse the image `qnx800:latest` and the container `qnx-build`. An existing container is not deleted.

**You should see** `Hello QNX!` from the guest, then `uname` and `pidin`. This is the run from 2026-11-14 after `./scripts/down.sh`. The whole script finished in 15 seconds. It did not rebuild the image. The full log is [docs/evidence/up.log](docs/evidence/up.log). The lines that show the guest are:

```text
OK   image already built: ~/qnxprojects/targets/qemu-qnx800-aarch64le/output/ifs.bin
==> Starting qemu-system-aarch64 (serial log: ~/qnxprojects/targets/qemu-qnx800-aarch64le/output/serial.log)
OK   SSH is accepting connections
qcc -Vgcc_ntoaarch64le -Wall -o hello-qnx hello-qnx.c
Hello QNX!
sysname=QNX release=8.0.0 machine=QEMU_virt version=2026/06/05-16:21:14EDT
QNX qnx-a64 8.0.0 2026/06/05-16:21:14EDT QEMU_virt aarch64le
       1 /proc/boot/procnto-smp-instr
```

The serial log for that boot, [docs/evidence/serial.log](docs/evidence/serial.log), ends with:

```text
Startup complete
QNX qnx-a64 8.0.0 2026/06/05-16:21:14EDT QEMU_virt aarch64le
```

Log in yourself. The QNX shell prompt is `# `, with no banner:

```bash
ssh -p 2222 -i ~/.ssh/id_ed25519 root@localhost
uname -a
```

`qconn` is forwarded to port 8000 on the Mac.

Running `./scripts/up.sh` again does not rebuild the image and does not start a second QEMU. The second run on this machine finished in 3 seconds and printed:

```text
OK   image already built: ~/qnxprojects/targets/qemu-qnx800-aarch64le/output/ifs.bin
OK   QEMU already running (pid 43997)
Hello QNX!
QNX qnx-a64 8.0.0 2026/06/05-16:21:14EDT QEMU_virt aarch64le
```

Full log: [docs/evidence/up-second.log](docs/evidence/up-second.log). There is no `mkqnximage` line in either log.

`QNX_QEMU_ACCEL=hvf` is not the default. On this image it stops in `gic_v3.c:966` and SSH never comes up. See [docs/PITFALLS.md](docs/PITFALLS.md).

## Evidence of QNX use

These files and commands are the proof that the program was built with the SDP 8.0 toolchain and executed on a QNX 8.0 guest, not on macOS.

| Proof | Where |
|-------|--------|
| Toolchain is `qcc -Vgcc_ntoaarch64le` from SDP 8.0 GCC 12.2.0 | `qcc -V` inside `qnx-build`, and the link line in [docs/evidence/up.log](docs/evidence/up.log) |
| Image was built with `mkqnximage --type=qemu --arch=aarch64le` | [scripts/build-image.sh](scripts/build-image.sh). `./scripts/up.sh` calls it only when `output/ifs.bin` is missing |
| `sshd-auth` is packaged into the image | [qemu-aarch64le/local/snippets/system_files.custom](qemu-aarch64le/local/snippets/system_files.custom) (`bin/sshd-auth=usr/libexec/sshd-auth`) and [qemu-aarch64le/local/snippets/ifs_files.custom](qemu-aarch64le/local/snippets/ifs_files.custom) (`[type=link] /usr/libexec/sshd-auth=/system/bin/sshd-auth`) |
| Guest identity | `uname -a` prints `QNX qnx-a64 8.0.0 2026/06/05-16:21:14EDT QEMU_virt aarch64le` |
| QNX kernel process | `pidin -F "%a %n"` lists pid 1 `/proc/boot/procnto-smp-instr`, plus `devb-virtio` and `sshd` |
| The example is a QNX ELF | `file examples/hello-qnx/hello-qnx` prints `ELF 64-bit LSB pie executable, ARM aarch64` and interpreter `/usr/lib/ldqnx-64.so.2` |

Refresh the captured logs with:

```bash
./scripts/collect-evidence.sh
```

That writes `docs/evidence/versions.txt`, `docs/evidence/up.log`, and `docs/evidence/serial.log`. It does not record passwords or private keys.

After the guest is up:

```bash
./tests/smoke.sh
```

exits 0 when `Hello QNX!`, `8.0.0`, `aarch64le`, `procnto-smp-instr`, and the `ldqnx-64.so.2` interpreter are all present. Otherwise it exits 1.

GitHub Actions runs `shellcheck` and `bash -n` on the scripts. It does not install SDP 8.0. The license cannot be checked out in CI.

## Acknowledgements

- [How to use macOS to develop for QNX](https://qnx.software/en/blog/2026/how-to-use-macos-to-develop-for-qnx) is the official starting point. Its Docker files live in [gitlab.com/qnx/projects/docker-mac](https://gitlab.com/qnx/projects/docker-mac). That Dockerfile uses `ubuntu:20.04`, and the Python 3.11 packages it installs are no longer published for that release. `scripts/setup-docker.sh` switches the base image to Ubuntu 22.04 in a cache clone. The GitLab issue that reported this is not linked here yet.
- [genryjiang/qnx-setup](https://github.com/genryjiang/qnx-setup) is the source of the Mac QEMU launch approach (`-machine virt`, serial log, TCG).
- [OTP on QNX, from the Erlang Ecosystem Foundation](https://erlef.org/blog/eef/otp-qnx-port) describes QNX on Apple Silicon with QEMU.
- [`mkqnximage` in the QNX SDP 8.0 Utilities Reference](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.utilities/topic/m/mkqnximage.html) is the image builder this repo calls.

## More documentation

- [docs/TUTORIAL.md](docs/TUTORIAL.md) — codelab
- [docs/PITFALLS.md](docs/PITFALLS.md) — each failure, with the command output
- [AGENTS.md](AGENTS.md) — notes for coding agents

## License

Apache License 2.0. See [LICENSE](LICENSE).
