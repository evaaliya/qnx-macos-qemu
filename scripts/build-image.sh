#!/usr/bin/env bash
# Build a QNX 8.0 aarch64le QEMU image inside the existing Docker qnx-build container.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="${TARGET_DIR:-$HOME/qnxprojects/targets/qemu-qnx800-aarch64le}"
CONTAINER="${QNX_BUILD_CONTAINER:-qnx-build}"

"$ROOT/scripts/check-prereqs.sh"

mkdir -p "$TARGET_DIR/local/snippets"
cp -f "$ROOT/qemu-aarch64le/local/snippets/"*.custom "$TARGET_DIR/local/snippets/"
cp -f "$ROOT/qemu-aarch64le/run.sh" "$TARGET_DIR/run.sh"
chmod +x "$TARGET_DIR/run.sh"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Starting container $CONTAINER ..."
  docker start "$CONTAINER" >/dev/null
fi

PUBKEY_IN_CONTAINER="/home/$(id -un)/.ssh/id_ed25519.pub"
SSH_IDENT_ARGS=(--ssh-ident=none)
if docker exec "$CONTAINER" test -f "$PUBKEY_IN_CONTAINER"; then
  SSH_IDENT_ARGS=(--ssh-ident="$PUBKEY_IN_CONTAINER")
  echo "Using container path pubkey: $PUBKEY_IN_CONTAINER"
fi

echo "Building image in $CONTAINER -> $TARGET_DIR"
docker exec "$CONTAINER" bash -lc "
set -e
source /usr/local/qnx/env/bin/activate
source \"\$HOME/qnx800/qnxsdp-env.sh\"
cd \"$TARGET_DIR\"
# TARGET_DIR is a host path under \$HOME; inside the container HOME is /home/\$USER
cd \"\$HOME/qnxprojects/targets/qemu-qnx800-aarch64le\"
mkqnximage --type=qemu --arch=aarch64le --hostname=qnx-a64 --clean --build --noprompt ${SSH_IDENT_ARGS[*]}
ls -la output/ifs.bin output/disk-qemu.vmdk output/disk-qemu
"

echo
echo "Build finished. On the Mac host (not inside Docker), run:"
echo "  cd $TARGET_DIR && ./run.sh"
echo "Then SSH:"
echo "  ssh -p 2222 -i ~/.ssh/id_ed25519 root@localhost"
