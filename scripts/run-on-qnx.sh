#!/usr/bin/env bash
# Build a project with qcc -Vgcc_ntoaarch64le inside qnx-build, copy the
# binary to the guest, run it, and print its output.
# The binary name is the project directory name. The Makefile must produce that file.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

if [[ $# -ne 1 ]]; then
  qnx_die "usage: ./scripts/run-on-qnx.sh PATH"
fi
if [[ ! -d "$1" ]]; then
  qnx_die "Not a directory: $1"
fi
proj="$(cd "$1" && pwd)"
bin_name="$(basename "$proj")"

if [[ ! -f "$QNX_SSH_KEY" ]]; then
  qnx_die "SSH private key $QNX_SSH_KEY is missing. Run ./scripts/ensure-ssh-key.sh and rebuild the image."
fi
if [[ ! -f "$proj/Makefile" ]]; then
  qnx_die "No Makefile in $proj. ./scripts/new-project.sh writes one that runs qcc -Vgcc_ntoaarch64le."
fi

proj_rel="$(qnx_home_rel "$proj")" || qnx_die "This project is not under \$HOME ($proj). The qnx-build container bind-mounts your home directory at /home/<user> and has no /Users tree, so qcc cannot see it. Put the project in ~/qnxprojects."
qnx_reject_odd_path "$proj_rel"
qnx_reject_odd_path "$bin_name"

qnx_require_container
if ! qnx_qemu_running; then
  qnx_die "QEMU is not running. Start it with ./scripts/up.sh, then run this again."
fi

qnx_info "Compiling $proj_rel in $QNX_BUILD_CONTAINER"
docker exec -i "$QNX_BUILD_CONTAINER" bash -s -- "$proj_rel" <<'EOS'
set -eo pipefail
rel="$1"
source /usr/local/qnx/env/bin/activate
source "$HOME/qnx800/qnxsdp-env.sh"
cd "$HOME/$rel"
echo "Container build directory: $(pwd)"
command -v qcc
qcc -V 2>&1 | awk 'NR==1 || /gcc_ntoaarch64le$/ { print }'
make clean
make
EOS

binary="$proj/$bin_name"
if [[ ! -f "$binary" ]]; then
  qnx_die "Build did not produce $binary. The Makefile must write a file named $bin_name."
fi
file "$binary"

qnx_info "Copying $bin_name to the guest"
qnx_scp_to_guest "$binary" "/tmp/$bin_name"

qnx_info "Running /tmp/$bin_name on the guest"
qnx_ssh "chmod +x /tmp/$bin_name && /tmp/$bin_name"
