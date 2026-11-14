#!/usr/bin/env bash
# Shared helpers for the macOS + Docker + QEMU QNX scripts.
# Source this file; do not execute it.

if [[ -n "${QNX_MACOS_QEMU_LIB:-}" ]]; then
  return 0
fi
QNX_MACOS_QEMU_LIB=1

: "${QNX_SDP:=$HOME/qnx800}"
: "${QNX_ARCH:=aarch64le}"
: "${QNX_BUILD_CONTAINER:=qnx-build}"
: "${QNX_BUILD_IMAGE:=qnx800}"
: "${QNX_TARGET_DIR:=$HOME/qnxprojects/targets/qemu-qnx800-aarch64le}"
: "${QNX_SSH_PORT:=2222}"
: "${QNX_SSH_USER:=root}"
: "${QNX_SSH_KEY:=$HOME/.ssh/id_ed25519}"
: "${QNX_HOSTNAME:=qnx-a64}"

# Docker Desktop 4.89 and later installs the CLI here and adds it to PATH for new
# terminals. A script started from an agent shell may not have that PATH yet.
if [[ -x "${HOME}/.docker/bin/docker" ]]; then
  case ":${PATH}:" in
    *":${HOME}/.docker/bin:"*) ;;
    *) export PATH="${HOME}/.docker/bin:${PATH}" ;;
  esac
fi

# Which Mac this is. Prints one of:
#   apple-silicon          arm64 hardware, native shell
#   apple-silicon-rosetta  arm64 hardware, but this shell runs as x86_64 under Rosetta
#   intel                  x86_64 hardware
# `uname -m` alone cannot tell the last two apart: both print x86_64.
# hw.optional.arm64 does not exist on Intel, so a failed read means 0.
qnx_host_kind() {
  local arm translated
  arm="$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)"
  translated="$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)"
  if [[ "$arm" == "1" && "$translated" == "1" ]]; then
    echo apple-silicon-rosetta
  elif [[ "$arm" == "1" ]]; then
    echo apple-silicon
  else
    echo intel
  fi
}

# Seconds ./scripts/up.sh waits for guest SSH. TCG on Intel has to translate
# every aarch64 instruction to x86_64, so it gets a longer default.
qnx_default_boot_timeout() {
  if [[ "$(qnx_host_kind)" == "intel" ]]; then
    echo 600
  else
    echo 180
  fi
}

qnx_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

qnx_info() {
  printf '==> %s\n' "$*"
}

qnx_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Something only a person can do: an account, a password, or a click.
# Agents must quote the line verbatim and wait. Never put a secret in it.
qnx_human() {
  printf 'HUMAN ACTION: %s\n' "$*"
}

# True when the person has already exported both variables. Does not print them.
qnx_myqnx_env_set() {
  [[ -n "${MYQNX_USER:-}" && -n "${MYQNX_PASSWORD:-}" ]]
}

# Path relative to $HOME. The qnx-build container bind-mounts the Mac home
# directory at /home/<user>, so a host path under $HOME is $HOME/<rel> there.
qnx_home_rel() {
  local path="$1"
  case "$path" in
    "$HOME"/*)
      printf '%s\n' "${path#"$HOME"/}"
      ;;
    *)
      return 1
      ;;
  esac
}

qnx_reject_odd_path() {
  local rel="$1"
  case "$rel" in
    *[!A-Za-z0-9/_.-]*)
      qnx_die "refusing to pass this path into the container (unsupported character): $rel"
      ;;
  esac
}

qnx_qemu_pid() {
  local pidfile="$QNX_TARGET_DIR/output/qemu.pid"
  local pid
  [[ -f "$pidfile" ]] || return 1
  pid="$(tr -cd '0-9' <"$pidfile")"
  [[ -n "$pid" ]] || return 1
  printf '%s\n' "$pid"
}

qnx_qemu_command() {
  ps -p "$1" -o command= 2>/dev/null || true
}

qnx_qemu_running() {
  local pid cmd
  pid="$(qnx_qemu_pid)" || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  cmd="$(qnx_qemu_command "$pid")"
  case "$cmd" in
    *qemu-system-aarch64*) return 0 ;;
    *) return 1 ;;
  esac
}

qnx_ssh_options() {
  mkdir -p "$QNX_TARGET_DIR/output"
  printf '%s\n' \
    -p "$QNX_SSH_PORT" \
    -i "$QNX_SSH_KEY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    -o "UserKnownHostsFile=$QNX_TARGET_DIR/output/ssh_known_hosts" \
    -o ConnectTimeout="${QNX_SSH_CONNECT_TIMEOUT:-8}"
}

qnx_ssh() {
  local -a opts=()
  local line
  while IFS= read -r line; do
    opts+=("$line")
  done < <(qnx_ssh_options)
  # The remote command is the caller's argument. It is meant to expand here.
  # shellcheck disable=SC2029
  ssh "${opts[@]}" "$QNX_SSH_USER@localhost" "$@"
}

qnx_scp_to_guest() {
  local src="$1"
  local dest="$2"
  mkdir -p "$QNX_TARGET_DIR/output"
  scp -P "$QNX_SSH_PORT" \
    -i "$QNX_SSH_KEY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    -o "UserKnownHostsFile=$QNX_TARGET_DIR/output/ssh_known_hosts" \
    -o ConnectTimeout="${QNX_SSH_CONNECT_TIMEOUT:-8}" \
    "$src" "$QNX_SSH_USER@localhost:$dest"
}

qnx_container_exists() {
  docker ps -a --format '{{.Names}}' | grep -qx "$QNX_BUILD_CONTAINER"
}

qnx_container_running() {
  docker ps --format '{{.Names}}' | grep -qx "$QNX_BUILD_CONTAINER"
}

qnx_require_container() {
  if ! qnx_container_exists; then
    qnx_die "Docker container '$QNX_BUILD_CONTAINER' does not exist. Run ./scripts/setup-docker.sh"
  fi
  if ! qnx_container_running; then
    qnx_info "Starting container $QNX_BUILD_CONTAINER"
    docker start "$QNX_BUILD_CONTAINER" >/dev/null
  fi
}

# Locate the QNX Software Center command-line tool. Do not assume one install path.
qnx_find_qsc_clt() {
  local c
  local candidates=()
  candidates+=(
    "/Applications/QNX Software Center.app/Contents/Eclipse/qnxsoftwarecenter_clt"
    "$HOME/Applications/QNX Software Center.app/Contents/Eclipse/qnxsoftwarecenter_clt"
  )
  if command -v mdfind >/dev/null 2>&1; then
    while IFS= read -r c; do
      [[ -n "$c" ]] && candidates+=("$c")
    done < <(mdfind 'kMDItemFSName == "qnxsoftwarecenter_clt"' 2>/dev/null || true)
  fi
  if [[ -d /Applications || -d "$HOME/Applications" ]]; then
    while IFS= read -r c; do
      [[ -n "$c" ]] && candidates+=("$c")
    done < <(find /Applications "$HOME/Applications" -maxdepth 6 -name qnxsoftwarecenter_clt -type f 2>/dev/null || true)
  fi
  local seen=" "
  for c in "${candidates[@]+"${candidates[@]}"}"; do
    [[ -n "$c" && -x "$c" ]] || continue
    case "$seen" in
      *" $c "*) continue ;;
    esac
    seen="$seen$c "
    printf '%s\n' "$c"
    return 0
  done
  return 1
}
