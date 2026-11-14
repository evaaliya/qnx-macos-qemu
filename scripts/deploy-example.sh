#!/usr/bin/env bash
# Cross-compile examples/hello-qnx, copy it to the guest, and run it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/run-on-qnx.sh" "$ROOT/examples/hello-qnx"
