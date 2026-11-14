#!/usr/bin/env bash
# Check the QNX packages a QEMU aarch64le image needs, and install them when asked.
# myQNX credentials are read from MYQNX_USER and MYQNX_PASSWORD only. They are never written to disk.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

ok=1
missing_ids=""

manual_qemu_packages() {
  qnx_human "The QEMU target files are missing. In your own terminal, not in chat, run: export MYQNX_USER='you@example.com' && export MYQNX_PASSWORD='your-myqnx-password' && ./scripts/check-prereqs.sh . Do not paste the password into the agent chat. Or open QNX Software Center, select the installation at ~/qnx800, open Manage Installation, then Available, search for qemu, and install com.qnx.qnx800.target.qemuvirt (QEMU Virtualization Drivers, Startup) and com.qnx.qnx800.target.driver.virtio.devb (QNX SDP 8.0 Virtualization Drivers, Block)."
}

note_file() {
  local path="$1"
  local pkg="$2"
  local hint="$3"
  if [[ -e "$path" ]]; then
    echo "OK   $path"
    return 0
  fi
  echo "MISS $path"
  echo "     $hint"
  if [[ -n "$pkg" ]]; then
    echo "     package: $pkg"
    if [[ -z "$missing_ids" ]]; then
      missing_ids="$pkg"
    else
      missing_ids="$missing_ids,$pkg"
    fi
  else
    ok=0
  fi
}

install_missing() {
  local clt
  if [[ ! -f "$QNX_SDP/qnxsdp-env.sh" ]]; then
    echo "error: $QNX_SDP is not an SDP install (qnxsdp-env.sh is missing)." >&2
    if qnx_myqnx_env_set && qnx_find_qsc_clt >/dev/null; then
      echo "MYQNX_USER and MYQNX_PASSWORD are already set. Run qnxsoftwarecenter_clt -mirror, then -installBaseline com.qnx.qnx800 -destination $QNX_SDP. Do not pass -cleanInstall. Do not print the password." >&2
    else
      qnx_human "QNX SDP 8.0 is not in ~/qnx800 (qnxsdp-env.sh is missing). In your own terminal, not in chat, export MYQNX_USER and MYQNX_PASSWORD. Or open QNX Software Center, click Add Installation, choose QNX Software Development Platform 8.0 [com.qnx.qnx800], and set the destination to ~/qnx800. https://www.qnx.com/developers/docs/qsc/com.qnx.doc.qsc.inst_larg_org/topic/create_headless_installation_linux_macos.html"
    fi
    ok=0
    return
  fi
  if ! qnx_myqnx_env_set; then
    manual_qemu_packages
    ok=0
    return
  fi
  if ! clt="$(qnx_find_qsc_clt)"; then
    echo "error: qnxsoftwarecenter_clt was not found on this Mac." >&2
    qnx_human "Install QNX Software Center for macOS from your myQNX account: https://www.qnx.com/download/group.html?programid=29178 and open the installer. If macOS asks to install Rosetta, click Install and enter your Mac password. https://support.apple.com/en-us/102527"
    ok=0
    return
  fi
  echo "OK   qnxsoftwarecenter_clt ($clt)"
  qnx_info "Installing $missing_ids into $QNX_SDP"
  # Password is an argument because that is the CLT's interface. It is not echoed or stored.
  if ! "$clt" \
    -destination "$QNX_SDP" \
    -myqnx.user "$MYQNX_USER" \
    -myqnx.password "$MYQNX_PASSWORD" \
    -installPackage "$missing_ids"; then
    echo "error: qnxsoftwarecenter_clt -installPackage failed." >&2
    manual_qemu_packages
    ok=0
    return
  fi
  missing_ids=""
  note_file \
    "$QNX_SDP/target/qnx/$QNX_ARCH/boot/sys/startup-qemu-virt" \
    "" \
    "still missing after install"
  note_file \
    "$QNX_SDP/target/qnx/$QNX_ARCH/sbin/devb-virtio" \
    "" \
    "still missing after install"
}

echo "SDP: $QNX_SDP"
note_file \
  "$QNX_SDP/target/qnx/$QNX_ARCH/boot/sys/startup-qemu-virt" \
  "com.qnx.qnx800.target.qemuvirt" \
  "QEMU Virtualization Drivers (Startup)"
note_file \
  "$QNX_SDP/target/qnx/$QNX_ARCH/sbin/devb-virtio" \
  "com.qnx.qnx800.target.driver.virtio.devb" \
  "Virtualization Drivers (Block)"
note_file \
  "$QNX_SDP/target/qnx/$QNX_ARCH/usr/libexec/sshd-auth" \
  "" \
  "OpenSSH helper from the SDP (usually already installed). mkqnximage still needs the snippets in qemu-aarch64le/local/snippets."

if [[ -n "$missing_ids" ]]; then
  install_missing
fi

if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
  echo "MISS qemu-system-aarch64 (host). Install: brew install qemu"
  ok=0
else
  qver="$(qemu-system-aarch64 --version 2>/dev/null | awk 'NR==1 { print; exit }' || true)"
  echo "OK   qemu-system-aarch64 ${qver}"
fi

if ! docker info >/dev/null 2>&1; then
  echo "MISS Docker daemon (needed for mkqnximage via the $QNX_BUILD_CONTAINER container)"
  ok=0
else
  echo "OK   Docker"
fi

if [[ "$ok" -ne 1 ]]; then
  echo
  echo "Fix the MISS lines above, then re-run: ./scripts/check-prereqs.sh"
  exit 1
fi

echo
echo "Prereqs look good."
