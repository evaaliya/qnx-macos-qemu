# Pitfalls: QNX SDP 8.0 on a Mac

Each entry is a failure we hit bringing up a QNX 8.0 `aarch64le` QEMU guest on macOS. The scripts in this repository already apply the fix. The notes are here so the next person can recognise the symptom.

Pitfalls 1 to 9 were checked on 2026-11-14 on a MacBook Air (Apple Silicon), macOS 15.8.3, Docker Desktop 29, Homebrew QEMU 11.1.3, SDP 8.0 in `~/qnx800`.

## 1. Docker image build cannot find Python 3.11

**Symptom.** `docker build` stops in the upstream Dockerfile with:

```text
E: Unable to locate package python3.11-dev
E: Unable to locate package python3.11-venv
E: Unable to locate package python3.11-distutils
```

**Cause.** [gitlab.com/qnx/projects/docker-mac](https://gitlab.com/qnx/projects/docker-mac) used `FROM ubuntu:20.04`. The deadsnakes PPA no longer publishes Python 3.11 for Ubuntu 20.04 (focal).

**Fix.** Change the base image to Ubuntu 22.04 before building. `scripts/setup-docker.sh` clones that repository into `~/.cache/qnx-macos-qemu/docker-mac` and runs:

```bash
sed -i '' 's/ubuntu:20.04/ubuntu:22.04/g' Dockerfile
```

Verified on a fresh clone: the `FROM` line changed from `ubuntu:20.04` to `ubuntu:22.04`. The Docker image `qnx800:latest` on this machine was already built from that change, so this session did not rebuild it. Rebuilding the image takes about 30 minutes the first time. On Apple Silicon, Docker prints that the `linux/amd64` image may be slow under emulation. That warning is harmless.

## 2. `Host file 'startup-qemu-virt' not available`

**Symptom.** `mkqnximage --type=qemu --arch=aarch64le --build` fails with `Host file 'startup-qemu-virt' not available`.

**Cause.** The file `~/qnx800/target/qnx/aarch64le/boot/sys/startup-qemu-virt` comes from package `com.qnx.qnx800.target.qemuvirt` (QEMU Virtualization Drivers (Startup)). A default SDP install does not include it. The QNX Software Center lists it under Available when you search for `qemu`.

**Fix.** Install that package into `~/qnx800`. `scripts/check-prereqs.sh` does it when `MYQNX_USER` and `MYQNX_PASSWORD` are set. Otherwise it prints the click-path: QNX Software Center → Manage Installation → Available → search `qemu`. On this machine the file is present.

## 3. Boot stops with `Unable to access /dev/hd0`

**Symptom.** The serial log starts QNX, then the guest cannot mount its disk: `Unable to access /dev/hd0`.

**Cause.** The disk is a virtio block device (`virtio-blk-device` in `qemu-aarch64le/run.sh`). The driver is `devb-virtio`, from package `com.qnx.qnx800.target.driver.virtio.devb` (Virtualization Drivers (Block)). Without that binary, `mkqnximage` has nothing to put in the image to talk to the virtual disk.

**Fix.** Install the package the same way as in pitfall 2. After a good boot the serial log contains `devb` and `Direct-Access` / `VIRTIO`, and `pidin` shows `devb-virtio`. Both were true on the guest booted here on 2026-11-14.

## 4. QEMU 11 has no `virt` machine `virt-4.2`

**Symptom.** `qemu-system-aarch64` exits immediately with an error that machine type `virt-4.2` is not a valid machine.

**Cause.** Older QNX launch examples pass `-machine virt-4.2`. QEMU 11.1.3, the Homebrew version on this Mac, no longer provides that versioned machine.

**Fix.** `qemu-aarch64le/run.sh` passes `-machine virt`. After boot, `uname -a` on the guest contains `QEMU_virt`.

## 5. QEMU dies as soon as the launcher returns

**Symptom.** The guest prints `Startup complete` and answers SSH during the launcher, then the next SSH gets `Connection refused`. `output/qemu.pid` still contains a pid, and that pid is gone. An empty `output/qemu.host.log` is normal for this failure: the process is killed, it does not print an error.

**Cause.** Two separate things look the same.

- QEMU's serial device was attached to the terminal. Closing the terminal delivers SIGHUP, and a foreground `-nographic` process goes away with it.
- A background job started by `./scripts/up.sh` stays in that shell's process group. When the script exits, the group is torn down and QEMU dies even if `nohup` was used.

**Fix.** `run.sh` sends serial to `output/serial.log` (`-serial file:output/serial.log`) and does not open a monitor. `scripts/up.sh` starts that script in a new session (`python3` calls `setsid` before exec), so QEMU is not in the script's process group. Checked after `./scripts/up.sh` had returned: a new shell still saw `qemu-system-aarch64` listening on port 2222, and `ssh -p 2222 -i ~/.ssh/id_ed25519 root@localhost uname -a` printed the QNX 8.0.0 line.

`./scripts/down.sh` stops the process recorded in `output/qemu.pid`. It will not kill a pid that is not `qemu-system-aarch64`.

## 6. `sshd` is in the image but login never works

**Symptom.** The serial log says `Starting sshd`, and a TCP connection to port 2222 resets or closes. `sshd` is looking for `/usr/libexec/sshd-auth`.

**Cause.** The stock `mkqnximage` SSH section does not copy `sshd-auth` into the system partition, and the IFS does not point `/usr/libexec/sshd-auth` at that copy. The binary itself is already in the SDP at `target/qnx/aarch64le/usr/libexec/sshd-auth`.

**Fix.** Two snippets, copied into the image tree by `scripts/build-image.sh`:

- `qemu-aarch64le/local/snippets/system_files.custom` adds `bin/sshd-auth=usr/libexec/sshd-auth` to the system partition.
- `qemu-aarch64le/local/snippets/ifs_files.custom` adds `[type=link] /usr/libexec/sshd-auth=/system/bin/sshd-auth`.

After the rebuild on 2026-11-14 those lines are in `output/build/system.build` and `output/build/ifs.build`, and SSH as `root` with the ed25519 key gets a shell. `pidin` shows `sshd` and `sshd-session`.

## 7. `build-image.sh` fails inside Docker on `cd /Users/...`

**Symptom.** `docker exec` exits immediately. With `set -e`, nothing after the `cd` runs. `mkqnximage` never starts.

**Cause.** The container bind-mounts the Mac home directory at `/home/<user>`. It does not have `/Users`. Expanding `TARGET_DIR` on the Mac produces `~/qnxprojects/...`, and that path does not exist in the container. Confirmed with `docker exec qnx-build` — `cd` to the `/Users/...` path returns `No such file or directory`, while `$HOME` in the container is `/home/<user>`.

**Fix.** `scripts/build-image.sh` strips the home prefix on the Mac and `cd`s to `$HOME/<that relative path>` inside the container. The rebuild log from 2026-11-14 contains:

```text
Container build directory: /home/<user>/qnxprojects/targets/qemu-qnx800-aarch64le
```

The image directory has to live under your home folder. The script stops if it does not.

## 8. The image builds, and SSH still says `Permission denied`

**Symptom.** `mkqnximage` succeeds, the guest boots, and `ssh -p 2222 root@localhost` rejects the key.

**Cause.** `mkqnximage` copies the public key you pass with `--ssh-ident` into the guest at build time. A key created after the build is not in `authorized_keys`. Passing the Mac path `/Users/.../.ssh/id_ed25519.pub` also fails, because the container sees that file at `/home/<user>/.ssh/id_ed25519.pub`.

**Fix.** `scripts/ensure-ssh-key.sh` creates `~/.ssh/id_ed25519` when it is missing and refuses to overwrite an existing key. `build-image.sh` runs that first, then tells `mkqnximage` to use `$HOME/.ssh/id_ed25519.pub` inside the container. On this machine the existing key was left unchanged (same SHA-256 before and after).

If you replace the key later, rebuild the image. A rebuild also creates a new host key. If SSH then says `REMOTE HOST IDENTIFICATION HAS CHANGED`:

```bash
ssh-keygen -R '[localhost]:2222'
```

The scripts keep their own `known_hosts` file in the image's `output/` directory, so they accept the new key on their own.

## 9. `QNX_QEMU_ACCEL=hvf` does not boot this image

**Symptom.** `QNX_QEMU_ACCEL=hvf ./scripts/up.sh` starts QEMU and then sits on `Waiting for SSH`. `output/serial.log` never reaches `Startup complete`. The whole file is:

```text
gic_v3_initialize(), setting 'use_memory_mapped_callouts'
gic_v3.c:966 -- ASSERT((use_memory_mapped_callouts == 0) || (gicc_paddr_base != (~(paddr_t)0))) failed!
```

**Checked.** 2026-11-14, after `./scripts/down.sh`. Command:

```bash
QNX_QEMU_ACCEL=hvf ./scripts/up.sh
```

Started at `2026-11-13T21:16:35Z`. Stopped at `2026-11-13T21:22:46Z` (6 minutes 11 seconds). SSH on port 2222 never accepted a connection. The process command line was:

```text
qemu-system-aarch64 -machine virt -cpu host -smp 2 -accel hvf ...
```

`output/qemu.host.log` for that run contained:

```text
warning: QNX_QEMU_ACCEL=hvf is not verified with this QNX image. The default is tcg.
qemu-system-aarch64: terminating on signal 15 from pid 43555 (<unknown process>)
```

The second line is `./scripts/down.sh` stopping that process. The warning text is what `run.sh` printed before this check was written down.

The saved logs are [docs/evidence/up-hvf.log](evidence/up-hvf.log), [docs/evidence/serial-hvf.log](evidence/serial-hvf.log), and [docs/evidence/qemu-host-hvf.log](evidence/qemu-host-hvf.log). The wait lines in `up-hvf.log` stop at the script's 70-second mark because the log buffer had not flushed the rest; the serial file itself did not gain another line in the full 6 minutes 11 seconds.

**Cause.** `-accel hvf -cpu host` exposes the Mac's GICv3 in a way this QNX startup does not accept. The startup assertion fires, and `sshd` never starts. QEMU itself stays running, so `up.sh` keeps waiting for SSH.

**Fix.** Leave the default: `-accel tcg -cpu cortex-a57`. On the same machine, immediately after the HVF process was stopped, `./scripts/up.sh` with the default accelerator finished in 15 seconds. The serial log reached `Startup complete` and:

```text
QNX qnx-a64 8.0.0 2026/06/05-16:21:14EDT QEMU_virt aarch64le
```

That run is [docs/evidence/up.log](evidence/up.log). It did not rebuild the image (`OK image already built`). A second `./scripts/up.sh` three seconds later printed `OK QEMU already running (pid 43997)` and did not call `mkqnximage`. That log is [docs/evidence/up-second.log](evidence/up-second.log).

## 10. `doctor.sh` says `MISS native arm64 shell`

**Symptom.** On an Apple Silicon Mac, `./scripts/doctor.sh` prints `Host: ... (x86_64, apple-silicon-rosetta)` and stops.

**Cause.** The terminal itself runs under Rosetta, so every program it starts, including `uname -m`, reports `x86_64`. Homebrew, QEMU, and the scripts then take the Intel paths on Apple Silicon hardware, which is slower and untested. The scripts tell this apart from a real Intel Mac with `sysctl hw.optional.arm64` (1 on Apple Silicon, also under Rosetta) and `sysctl.proc_translated` (1 under Rosetta). Checked on 2026-11-14 with `arch -x86_64 /bin/bash ./scripts/doctor.sh`.

**Fix.** Open a native terminal: Get Info on Terminal.app (or iTerm) and untick **Open using Rosetta**, or run `arch -arm64 /bin/zsh -l`. Then `uname -m` prints `arm64`.

## 11. Intel Mac: `Timed out ... waiting for SSH`, or `hvf` refused

**Not reproduced on Intel hardware.** These follow from how QEMU works and are checked by the scripts.

**Symptom.** `./scripts/up.sh` on an Intel Mac waits for SSH and gives up, or `run.sh` prints `QNX_QEMU_ACCEL=hvf needs Apple Silicon`.

**Cause.** HVF (Hypervisor.framework) runs a guest of the host's own CPU architecture. An Intel Mac has no aarch64 hardware to give the guest, so the only path is TCG, which translates every guest instruction. That is correct but slower, so `up.sh` waits up to 600 seconds on Intel instead of 180.

**Fix.** Leave `QNX_QEMU_ACCEL` unset. Look at the tail of `output/serial.log`: if it is still printing startup lines, the guest is slow, not broken, and `QNX_BOOT_TIMEOUT=1200 ./scripts/up.sh` gives it more time. If it stopped, compare its last line with pitfalls 2, 3, and 6.

## Container hangs on license (read-only ~/.qnx/license)
If the container stalls on start, check that ~/.qnx/license is writable and not read-only.