#!/usr/bin/env bash
# Cross-compile examples/hello-qnx in qnx-build, copy it to the guest, and run it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

if [[ ! -f "$QNX_SSH_KEY" ]]; then
  qnx_die "SSH private key $QNX_SSH_KEY is missing. Run ./scripts/ensure-ssh-key.sh and rebuild the image."
fi

qnx_require_container

repo_rel="$(qnx_home_rel "$ROOT")" || qnx_die "Clone this repository under $HOME. The container only mounts your home directory. Got: $ROOT"
qnx_reject_odd_path "$repo_rel"

if ! qnx_qemu_running; then
  qnx_die "QEMU is not running. Start it with ./scripts/up.sh or qemu-aarch64le/run.sh, then deploy."
fi

qnx_info "Compiling examples/hello-qnx in $QNX_BUILD_CONTAINER"
docker exec -i "$QNX_BUILD_CONTAINER" bash -s -- "$repo_rel" <<'EOS'
set -eo pipefail
rel="$1"
source /usr/local/qnx/env/bin/activate
source "$HOME/qnx800/qnxsdp-env.sh"
cd "$HOME/$rel/examples/hello-qnx"
echo "Container build directory: $(pwd)"
command -v qcc
qcc -V 2>&1 | awk 'NR==1 || /gcc_ntoaarch64le$/ { print }'
make clean
make
EOS

binary="$ROOT/examples/hello-qnx/hello-qnx"
if [[ ! -f "$binary" ]]; then
  qnx_die "Build did not produce $binary"
fi
file "$binary"

qnx_info "Copying hello-qnx to the guest"
qnx_scp_to_guest "$binary" /tmp/hello-qnx

qnx_info "Running /tmp/hello-qnx on the guest"
output="$(qnx_ssh 'chmod +x /tmp/hello-qnx && /tmp/hello-qnx')"
printf '%s\n' "$output"
case "$output" in
  *"Hello QNX!"*) ;;
  *) qnx_die "guest program did not print Hello QNX!" ;;
esac
