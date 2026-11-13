#!/usr/bin/env bash
# Create an ed25519 key before mkqnximage runs, without overwriting an existing key.
# mkqnximage bakes the public key into the guest. A key created afterwards cannot log in.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

key="$QNX_SSH_KEY"
pub="${key}.pub"

if [[ -f "$key" && -f "$pub" ]]; then
  echo "OK   SSH key already exists: $key"
  exit 0
fi

if [[ -e "$key" || -e "$pub" ]]; then
  qnx_die "SSH key pair at $key is incomplete. Not overwriting it. Move it aside and re-run."
fi

mkdir -p "$(dirname "$key")"
chmod 700 "$(dirname "$key")"
ssh-keygen -t ed25519 -f "$key" -N "" -C "qnx-macos-qemu@$(hostname -s)" >/dev/null
chmod 600 "$key"
echo "OK   created SSH key $key"
echo "     The public key will be passed to mkqnximage on the next image build."
