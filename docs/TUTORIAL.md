# Part 2: build your own program

The install is [README.md](../README.md). Start here only after `./scripts/up.sh` has printed `Hello QNX!`. This page does not repeat the account, the license, Docker, QEMU, or SDP.

Checked on 2026-11-14, Apple Silicon, macOS 15.8.3. The blocks below are that run. Where the terminal printed an absolute home path, this page writes the home directory as `~` and the account name as `<user>`. Nothing else in those blocks was changed.

## 1. Create a project

From the clone:

```bash
./scripts/new-project.sh mac-hello
```

```text
Created ~/qnxprojects/mac-hello
  ~/qnxprojects/mac-hello/Makefile
  ~/qnxprojects/mac-hello/main.c
  ~/qnxprojects/mac-hello/.vscode/tasks.json
```

`NAME` is one word of letters, numbers, dots, underscores, or hyphens. The directory is always `~/qnxprojects/NAME`. The script stops if that directory already exists, and it stops if the project would not stay under `$HOME`. The container bind-mounts the home directory and has no `/Users` tree, so `qcc` cannot see a project anywhere else.

`~/qnxprojects/mac-hello/.vscode/tasks.json` has one task, labeled `Build and run on QNX`. Its command is `${env:HOME}/qnx-macos-qemu/scripts/run-on-qnx.sh` with the argument `${workspaceFolder}`.

## 2. Change the program

`main.c` starts as `printf("hello from mac-hello\n")`. This run replaced that string:

```c
#include <stdio.h>

int main(void)
{
    printf("built on this Mac\n");
    return 0;
}
```

## 3. Build and run it on the guest

The guest has to be running (`./scripts/up.sh`). Then:

```bash
./scripts/run-on-qnx.sh ~/qnxprojects/mac-hello
```

```text
==> Compiling qnxprojects/mac-hello in qnx-build
QNX_HOST=/home/<user>/qnx800/host/linux/x86_64
QNX_TARGET=/home/<user>/qnx800/target/qnx
MAKEFLAGS=-I/home/<user>/qnx800/target/qnx/usr/include
Container build directory: /home/<user>/qnxprojects/mac-hello
/home/<user>/qnx800/host/linux/x86_64/usr/bin/qcc
cc: targets available in /home/<user>/qnx800/host/linux/x86_64/etc/qcc:
	12.2.0,gcc_ntoaarch64le
rm -f mac-hello
qcc -Vgcc_ntoaarch64le -Wall -o mac-hello main.c
~/qnxprojects/mac-hello/mac-hello: ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /usr/lib/ldqnx-64.so.2, BuildID[md5/uuid]=e9879ace612aed3a09d4b478fa581959, with debug_info, not stripped
==> Copying mac-hello to the guest
==> Running /tmp/mac-hello on the guest
built on this Mac
```

The binary name is the directory name. The Makefile has to produce that file. `./scripts/deploy-example.sh` is this same script pointed at `examples/hello-qnx`. During the same boot, `./scripts/up.sh` ran that example and the guest printed `Hello QNX!`.

## 4. Logs and processes on the guest

SSH uses port 2222 and the key `./scripts/ensure-ssh-key.sh` created. From the Mac:

```bash
ssh -p 2222 -i ~/.ssh/id_ed25519 \
  -o BatchMode=yes -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile=~/qnxprojects/targets/qemu-qnx800-aarch64le/output/ssh_known_hosts \
  root@localhost
```

On that shell, `slog2info` prints the system log and `pidin` prints processes. This boot:

```text
PIDIN
     pid name
       1 /proc/boot/procnto-smp-instr
       3 proc/boot/slogger2
   12292 proc/boot/devc-serpl011
   20486 proc/boot/ksh
   24581 proc/boot/fsevmgr
   28679 proc/boot/devb-virtio
   94216 system/bin/random
  106505 system/bin/pipe
  118794 system/bin/devc-pty
  122891 system/bin/dumper
  126988 system/bin/io-sock
  188432 system/bin/dhcpcd
  213006 system/bin/sshd
  217101 system/bin/qconn
  221199 system/bin/mqueue
  245778 system/bin/io-usb-otg
```

The numbers are from this boot. The names are what to look for: pid 1 is `procnto-smp-instr`, and `sshd` is the process that accepted the login.

`slog2info` printed the boot log, including:

```text
Nov 14 03:11:48.836                 io_sock.126988          main_buffer     32  iousb0: <io-usb-otg> on QNX
Nov 14 03:11:48.846                 io_sock.126988          main_buffer     32  device_attach: iousb0 attach returned 6
```

The same command also printed `sshd-session` lines for the public-key login from `10.0.2.2`. The key fingerprint is omitted here.

## When the script stops

A slash in the name:

```text
$ ./scripts/new-project.sh 'foo/bar'
error: NAME must be one directory name made of letters, numbers, dots, underscores, or hyphens. A slash would put the project somewhere other than ~/qnxprojects. Got: foo/bar
```

A directory outside the home directory:

```text
$ ./scripts/run-on-qnx.sh /tmp/not-home-qnx
error: This project is not under $HOME (/tmp/not-home-qnx). The qnx-build container bind-mounts your home directory at /home/<user> and has no /Users tree, so qcc cannot see it. Put the project in ~/qnxprojects.
```

Boot failures are [docs/PITFALLS.md](PITFALLS.md).
