#!/usr/bin/env bash
# Build a QNX SDP 8.0 aarch64le QEMU image inside the qnx-build container.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

TARGET_DIR="${TARGET_DIR:-$QNX_TARGET_DIR}"
QNX_TARGET_DIR="$TARGET_DIR"

"$ROOT/scripts/check-prereqs.sh"
"$ROOT/scripts/ensure-ssh-key.sh"
qnx_require_container

if qnx_qemu_running; then
  qnx_die "QEMU is running and has the image open. Run ./scripts/down.sh, then build again."
fi

mkdir -p "$TARGET_DIR"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
QNX_TARGET_DIR="$TARGET_DIR"

rel="$(qnx_home_rel "$TARGET_DIR")" || qnx_die "TARGET_DIR must be inside $HOME so the container can see it. Got: $TARGET_DIR"
qnx_reject_odd_path "$rel"

mkdir -p "$TARGET_DIR/local/snippets"
cp -f "$ROOT/qemu-aarch64le/local/snippets/"*.custom "$TARGET_DIR/local/snippets/"
cp -f "$ROOT/qemu-aarch64le/run.sh" "$TARGET_DIR/run.sh"
chmod +x "$TARGET_DIR/run.sh"

qnx_info "Building in container $QNX_BUILD_CONTAINER at \$HOME/$rel"
qnx_info "Host directory: $TARGET_DIR"

# Do not cd to the Mac path (/Users/...). The container mount is $HOME -> /home/$USER.
docker exec -i "$QNX_BUILD_CONTAINER" bash -s -- "$rel" "$QNX_ARCH" "$QNX_HOSTNAME" <<'EOS'
set -eo pipefail
rel="$1"
arch="$2"
hostname="$3"
source /usr/local/qnx/env/bin/activate
source "$HOME/qnx800/qnxsdp-env.sh"
cd "$HOME/$rel"
echo "Container build directory: $(pwd)"
pubkey="$HOME/.ssh/id_ed25519.pub"
if [[ ! -f "$pubkey" ]]; then
  echo "error: $pubkey is not visible in the container. Create it on the Mac before building." >&2
  exit 1
fi
echo "Using SSH public key $pubkey"
mkqnximage \
  --type=qemu \
  --arch="$arch" \
  --hostname="$hostname" \
  --clean \
  --build \
  --noprompt \
  --ssh-ident="$pubkey"
ls -la output/ifs.bin output/disk-qemu.vmdk output/disk-qemu
EOS

rm -f "$TARGET_DIR/output/ssh_known_hosts"

echo
echo "Build finished."
echo "Start the guest from the Mac (not from Docker):"
echo "  ./scripts/up.sh"
echo "or:"
echo "  cd $TARGET_DIR && ./run.sh"
echo "Then:"
echo "  ssh -p $QNX_SSH_PORT -i $QNX_SSH_KEY $QNX_SSH_USER@localhost"
echo "If SSH reports a changed host key after this rebuild:"
echo "  ssh-keygen -R '[localhost]:$QNX_SSH_PORT'"
