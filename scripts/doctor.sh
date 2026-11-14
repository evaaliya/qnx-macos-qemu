#!/usr/bin/env bash
# Host checks. Does not install software and does not need the guest to be running.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

ok=1
bad() {
  printf 'MISS %s\n' "$*"
  ok=0
}

note() {
  printf 'NOTE %s\n' "$*"
}

docker_app_installed() {
  [[ -d /Applications/Docker.app || -d "$HOME/Applications/Docker.app" ]]
}

host_kind="$(qnx_host_kind)"
printf 'Host: %s %s (%s, %s)\n' "$(sw_vers -productName)" "$(sw_vers -productVersion)" "$(uname -m)" "$host_kind"

case "$host_kind" in
  apple-silicon)
    echo "OK   Apple Silicon (arm64). This is the path the logs in docs/evidence were captured on."
    ;;
  apple-silicon-rosetta)
    bad "native arm64 shell. This terminal runs as x86_64 under Rosetta on an Apple Silicon Mac."
    qnx_human "This terminal is x86_64 under Rosetta on an Apple Silicon Mac. Open Terminal.app, run: arch -arm64 /bin/zsh -l    then: cd ~/qnx-macos-qemu && ./scripts/doctor.sh"
    ;;
  intel)
    echo "OK   Intel Mac (x86_64). The guest is aarch64, so up.sh waits up to $(qnx_default_boot_timeout)s. This path has not been run: the author does not have an Intel Mac."
    if [[ "${QNX_QEMU_ACCEL:-tcg}" == "hvf" ]]; then
      bad "QNX_QEMU_ACCEL=hvf cannot work on Intel. Unset it."
    fi
    ;;
esac

if [[ "$host_kind" == "intel" ]]; then
  mem_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))
  if [[ "$mem_gb" -lt 8 ]]; then
    note "$mem_gb GB RAM. Docker Desktop and a 1 GB guest together are tight below 8 GB."
  fi
fi

need_qsc=0

if [[ -f "$QNX_SDP/qnxsdp-env.sh" ]]; then
  echo "OK   $QNX_SDP/qnxsdp-env.sh"
else
  bad "$QNX_SDP/qnxsdp-env.sh"
  need_qsc=1
  if qnx_myqnx_env_set && qnx_find_qsc_clt >/dev/null; then
    echo "     MYQNX_USER and MYQNX_PASSWORD are already set. Install the baseline with qnxsoftwarecenter_clt -mirror, then -installBaseline com.qnx.qnx800 -destination $QNX_SDP. Do not pass -cleanInstall. Do not print the password."
  else
    qnx_human "QNX SDP 8.0 is not in ~/qnx800 (qnxsdp-env.sh is missing). In your own terminal, not in chat, export MYQNX_USER and MYQNX_PASSWORD. Or open QNX Software Center, click Add Installation, choose QNX Software Development Platform 8.0 [com.qnx.qnx800], and set the destination to ~/qnx800. License: https://www.qnx.com/getqnx"
  fi
fi

qcc_host="$QNX_SDP/host/linux/x86_64/usr/bin/qcc"
if [[ -e "$qcc_host" ]]; then
  echo "OK   Linux host tools ($qcc_host)"
else
  bad "$qcc_host"
  need_qsc=1
  echo "     SDP 8.0 has no macOS compiler. The package id is com.qnx.qnx800.host.linux.x86_64 (QNX SDP Host Tools, Linux 64-bit)."
  if qnx_myqnx_env_set && qnx_find_qsc_clt >/dev/null; then
    echo "     MYQNX_USER and MYQNX_PASSWORD are already set. Install that id with qnxsoftwarecenter_clt -installPackage. Do not print the password."
  else
    qnx_human "Install com.qnx.qnx800.host.linux.x86_64 (QNX SDP Host Tools, Linux 64-bit) into ~/qnx800. In your own terminal, not in chat, export MYQNX_USER and MYQNX_PASSWORD. Or in QNX Software Center open Manage Installation, then Available, search Host Tools, and install QNX SDP Host Tools (Linux 64-bit). https://www.qnx.com/developers/docs/relnotes8.0/com.qnx.doc.release_notes/topic/8.0.1_prod_release_notes/8.0.1_host_tools.html"
  fi
fi

if [[ "$need_qsc" -eq 1 ]] && ! qnx_find_qsc_clt >/dev/null; then
  qsc_bin="/Applications/QNX Software Center.app/Contents/MacOS/qnxsoftwarecenter"
  if [[ -e "$qsc_bin" ]]; then
    qnx_human "qnxsoftwarecenter_clt was not found. Open QNX Software Center from the Applications folder. On this Mac that app is a Mach-O x86_64 binary, so if macOS asks to install Rosetta, click Install and enter your Mac password. https://support.apple.com/en-us/102527"
  else
    qnx_human "Install QNX Software Center for macOS from your myQNX account: https://www.qnx.com/download/group.html?programid=29178 and open the installer. If macOS asks to install Rosetta, click Install and enter your Mac password. https://support.apple.com/en-us/102527"
  fi
fi

check_cmd() {
  local cmd="$1"
  local hint="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK   $cmd ($(command -v "$cmd"))"
  else
    bad "$cmd"
    echo "     $hint"
  fi
}

if ! command -v brew >/dev/null 2>&1; then
  bad "brew"
  qnx_human "Install Homebrew from https://brew.sh . The installer asks you to confirm in the terminal and then asks for your Mac password: https://docs.brew.sh/Installation . Open a new terminal and run ./scripts/doctor.sh again."
fi

if [[ "$host_kind" == "intel" ]]; then
  qemu_hint="Install on the Mac: brew install qemu (updated Homebrew formulae no longer ship new Intel bottles, so this can compile from source: https://brew.sh/2026/09/13/homebrew-7.0.0/)"
else
  qemu_hint="Install on the Mac: brew install qemu"
fi
check_cmd git "Install on the Mac: brew install git"
check_cmd qemu-system-aarch64 "$qemu_hint"

if command -v docker >/dev/null 2>&1; then
  echo "OK   docker ($(command -v docker))"
elif [[ -x "$HOME/.docker/bin/docker" ]]; then
  echo "OK   docker ($HOME/.docker/bin/docker) is not on PATH"
  note "Add it for this shell: export PATH=\"\$HOME/.docker/bin:\$PATH\""
else
  bad "docker"
  if docker_app_installed; then
    echo "     Docker.app is installed, but the docker CLI is not on PATH. After the engine is up it is usually ~/.docker/bin/docker"
  else
    qnx_human "Install Docker Desktop for this Mac from https://docs.docker.com/desktop/setup/install/mac-install/ (Apple silicon download or Intel download). Open Docker.dmg, drag Docker to Applications, and double-click Docker.app. Click Accept on the Docker Subscription Service Agreement. Then run ./scripts/doctor.sh again."
  fi
fi

# A QEMU binary built for the other architecture still runs (Rosetta), but slowly.
if qemu_bin="$(command -v qemu-system-aarch64 2>/dev/null)"; then
  qemu_file="$(file -L "$qemu_bin" 2>/dev/null || true)"
  case "$host_kind:$qemu_file" in
    apple-silicon*:*arm64*|intel:*x86_64*) ;;
    apple-silicon*:*x86_64*)
      note "$qemu_bin is an x86_64 build running under Rosetta. Install the arm64 one: /opt/homebrew/bin/brew install qemu"
      ;;
    *)
      note "could not tell which architecture $qemu_bin is built for."
      ;;
  esac
fi
check_cmd python3 "python3 detaches QEMU so it keeps running after ./scripts/up.sh returns. Install it with: brew install python"
if command -v ssh >/dev/null 2>&1; then
  echo "OK   ssh ($(command -v ssh))"
else
  bad "ssh"
  qnx_human "ssh is missing. Run xcode-select --install and click Install on the macOS dialog, then run ./scripts/doctor.sh again."
fi
if command -v scp >/dev/null 2>&1; then
  echo "OK   scp ($(command -v scp))"
else
  bad "scp"
  qnx_human "scp is missing. Run xcode-select --install and click Install on the macOS dialog, then run ./scripts/doctor.sh again."
fi

if command -v docker >/dev/null 2>&1 || [[ -x "$HOME/.docker/bin/docker" ]]; then
  docker_bin="$(command -v docker 2>/dev/null || true)"
  if [[ -z "$docker_bin" ]]; then
    docker_bin="$HOME/.docker/bin/docker"
  fi
  if "$docker_bin" info >/dev/null 2>&1; then
    echo "OK   Docker daemon ($("$docker_bin" info --format '{{.Architecture}}' 2>/dev/null || echo unknown))"
  else
    bad "Docker daemon"
    if docker_app_installed; then
      echo "     Docker.app is installed. Start it with: open -a Docker"
      echo "     Wait until docker info succeeds, then re-run ./scripts/doctor.sh"
    else
      qnx_human "Install Docker Desktop for this Mac from https://docs.docker.com/desktop/setup/install/mac-install/ (Apple silicon download or Intel download). Open Docker.dmg, drag Docker to Applications, and double-click Docker.app. Click Accept on the Docker Subscription Service Agreement. Then run ./scripts/doctor.sh again."
    fi
  fi
fi

if [[ "$ok" -ne 1 ]]; then
  echo
  echo "Fix the MISS lines above, then re-run: ./scripts/doctor.sh"
  exit 1
fi

echo
echo "Host looks ready."
