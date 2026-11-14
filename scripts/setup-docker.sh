#!/usr/bin/env bash
# Clone the upstream QNX macOS Docker project into a cache directory, patch it, and
# create the qnx800 image plus the qnx-build container when they are missing.
# Does not vendor upstream files into this repository and does not delete an existing container.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

CACHE="${QNX_DOCKER_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/qnx-macos-qemu/docker-mac}"
UPSTREAM="${QNX_DOCKER_UPSTREAM:-https://gitlab.com/qnx/projects/docker-mac.git}"
# The upstream commit this repository was tested with (2025-04-29, "Add missing
# .qnxbashrc"). Its scripts are executed below, so a newer upstream is not
# picked up silently. Set QNX_DOCKER_UPSTREAM_REF to try another commit.
UPSTREAM_REF="${QNX_DOCKER_UPSTREAM_REF:-e2b8d0a4871f5f4284bbf9582aa081f4517eba31}"

if ! docker info >/dev/null 2>&1; then
  if [[ ! -d /Applications/Docker.app && ! -d "$HOME/Applications/Docker.app" ]]; then
    qnx_human "Install Docker Desktop for this Mac from https://docs.docker.com/desktop/setup/install/mac-install/ (Apple silicon download or Intel download). Open Docker.dmg, drag Docker to Applications, and double-click Docker.app. Click Accept on the Docker Subscription Service Agreement. Then re-run ./scripts/setup-docker.sh"
    exit 1
  fi
  qnx_die "Docker daemon is not running. Start Docker Desktop with: open -a Docker    Wait until docker info succeeds, then re-run ./scripts/setup-docker.sh"
fi

image_exists() {
  docker image inspect "${QNX_BUILD_IMAGE}:latest" >/dev/null 2>&1
}

scripts_dir_of() {
  local root="$1"
  if [[ -f "$root/docker-mac/Dockerfile" && -f "$root/docker-mac/docker-build-qnx-image.sh" ]]; then
    printf '%s\n' "$root/docker-mac"
    return 0
  fi
  if [[ -f "$root/Dockerfile" && -f "$root/docker-build-qnx-image.sh" ]]; then
    printf '%s\n' "$root"
    return 0
  fi
  return 1
}

patch_dockerfile() {
  local dockerfile="$1"
  if grep -q 'ubuntu:20.04' "$dockerfile"; then
    # macOS sed. Same substitution that makes the upstream Ubuntu 20.04 file buildable
    # after deadsnakes dropped Python 3.11 for focal.
    sed -i '' 's/ubuntu:20.04/ubuntu:22.04/g' "$dockerfile"
    echo "Patched $dockerfile: ubuntu:20.04 -> ubuntu:22.04"
  elif grep -q 'ubuntu:22.04' "$dockerfile"; then
    echo "Dockerfile already uses ubuntu:22.04 ($dockerfile)"
  else
    qnx_die "Dockerfile has neither ubuntu:20.04 nor ubuntu:22.04: $dockerfile"
  fi
}

ensure_cache() {
  local dir have
  if dir="$(scripts_dir_of "$CACHE")"; then
    have="$(git -C "$CACHE" rev-parse HEAD 2>/dev/null || true)"
    if [[ "$have" != "$UPSTREAM_REF" ]]; then
      echo "warning: cache $CACHE is at ${have:-an unknown commit}, not the tested $UPSTREAM_REF." >&2
    fi
    printf '%s\n' "$dir"
    return 0
  fi
  if [[ -e "$CACHE" ]]; then
    qnx_die "Cache $CACHE exists but does not contain the upstream Docker scripts. Remove that cache directory and re-run."
  fi
  if ! command -v git >/dev/null 2>&1; then
    qnx_die "git is required to clone $UPSTREAM"
  fi
  # Progress goes to stderr. Callers capture stdout as the scripts directory.
  qnx_info "Cloning $UPSTREAM into $CACHE at $UPSTREAM_REF" >&2
  mkdir -p "$(dirname "$CACHE")"
  git clone --quiet "$UPSTREAM" "$CACHE" >&2
  git -C "$CACHE" checkout --quiet --detach "$UPSTREAM_REF" >&2 \
    || qnx_die "Commit $UPSTREAM_REF is not in $UPSTREAM"
  dir="$(scripts_dir_of "$CACHE")" || qnx_die "Clone of $UPSTREAM did not contain docker-build-qnx-image.sh"
  printf '%s\n' "$dir"
}

start_if_stopped() {
  if qnx_container_running; then
    echo "OK   container $QNX_BUILD_CONTAINER is already running"
    return 0
  fi
  qnx_info "Starting existing container $QNX_BUILD_CONTAINER (it will not be recreated)"
  docker start "$QNX_BUILD_CONTAINER" >/dev/null
}

if image_exists && qnx_container_exists; then
  echo "OK   Docker image ${QNX_BUILD_IMAGE}:latest already exists"
  start_if_stopped
  exit 0
fi

if [[ "$QNX_BUILD_IMAGE" != "qnx800" || "$QNX_BUILD_CONTAINER" != "qnx-build" ]]; then
  qnx_die "The upstream scripts always tag the image qnx800 and name the container qnx-build."
fi

scripts_dir="$(ensure_cache)"
patch_dockerfile "$scripts_dir/Dockerfile"

if ! image_exists; then
  qnx_info "Building ${QNX_BUILD_IMAGE}:latest from $scripts_dir"
  echo "    The first build downloads Ubuntu packages and can take about 30 minutes."
  if [[ "$(qnx_host_kind)" == "intel" ]]; then
    echo "    The image is linux/amd64. On this Intel Mac it runs natively."
  else
    echo "    The image is linux/amd64. On Apple Silicon, Docker runs it under emulation."
  fi
  (
    cd "$scripts_dir"
    bash ./docker-build-qnx-image.sh
  )
fi

if qnx_container_exists; then
  start_if_stopped
  exit 0
fi

qnx_info "Creating container $QNX_BUILD_CONTAINER"
if ! (
  cd "$scripts_dir"
  bash ./docker-create-container.sh
); then
  if qnx_container_exists; then
    echo "Container $QNX_BUILD_CONTAINER already exists; leaving it in place."
    start_if_stopped
    exit 0
  fi
  qnx_die "docker-create-container.sh failed and $QNX_BUILD_CONTAINER does not exist."
fi

if ! qnx_container_running; then
  docker start "$QNX_BUILD_CONTAINER" >/dev/null
fi
echo "OK   container $QNX_BUILD_CONTAINER is running"
