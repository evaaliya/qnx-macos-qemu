#!/usr/bin/env bash
# Install git and QEMU with Homebrew when they are missing, start Docker Desktop,
# wait until the engine answers, then boot QNX with ./scripts/up.sh.
# Does not install QNX packages and does not read MYQNX_USER or MYQNX_PASSWORD.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

if ! command -v brew >/dev/null 2>&1; then
  qnx_human "Install Homebrew from https://brew.sh . The installer asks you to confirm in the terminal and then asks for your Mac password: https://docs.brew.sh/Installation . Open a new terminal and run ./scripts/bootstrap.sh again."
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  qnx_info "Installing git"
  brew install git
fi

if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
  qnx_info "Installing qemu"
  brew install qemu
fi

docker_app=""
if [[ -d /Applications/Docker.app ]]; then
  docker_app="/Applications/Docker.app"
elif [[ -d "$HOME/Applications/Docker.app" ]]; then
  docker_app="$HOME/Applications/Docker.app"
fi

if ! docker info >/dev/null 2>&1; then
  if [[ -z "$docker_app" ]]; then
    qnx_human "Install Docker Desktop for this Mac from https://docs.docker.com/desktop/setup/install/mac-install/ (Apple silicon download or Intel download). Open Docker.dmg, drag Docker to Applications, and double-click Docker.app. Click Accept on the Docker Subscription Service Agreement. Then run ./scripts/bootstrap.sh again."
    exit 1
  fi
  qnx_info "Starting Docker Desktop (open -a Docker)"
  open -a Docker
  wait_s="${QNX_DOCKER_WAIT:-180}"
  [[ "$wait_s" =~ ^[0-9]+$ ]] || qnx_die "QNX_DOCKER_WAIT must be a number of seconds. Got: $wait_s"
  deadline=$((SECONDS + wait_s))
  while (( SECONDS < deadline )); do
    if docker info >/dev/null 2>&1; then
      break
    fi
    sleep 3
  done
  if ! docker info >/dev/null 2>&1; then
    qnx_human "Docker Desktop was started with open -a Docker and the engine was not ready within ${wait_s} seconds. Click the whale menu. If a window asks you to accept the Docker Subscription Service Agreement, click Accept. https://docs.docker.com/desktop/setup/install/mac-install/ Then run ./scripts/bootstrap.sh again."
    exit 1
  fi
fi

echo "OK   Docker daemon is running"
exec "$ROOT/scripts/up.sh"
