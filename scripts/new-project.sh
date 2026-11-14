#!/usr/bin/env bash
# Create ~/qnxprojects/NAME: Makefile, main.c, and a VS Code task
# "Build and run on QNX". The project must stay under $HOME.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

if [[ $# -ne 1 || -z "$1" ]]; then
  qnx_die "usage: ./scripts/new-project.sh NAME"
fi
name="$1"
case "$name" in
  *[!A-Za-z0-9._-]*)
    qnx_die "NAME must be one directory name made of letters, numbers, dots, underscores, or hyphens. A slash would put the project somewhere other than ~/qnxprojects. Got: $name"
    ;;
esac

repo_rel="$(qnx_home_rel "$ROOT")" || qnx_die "This repository is not under \$HOME ($ROOT). The new project's Build task calls scripts/run-on-qnx.sh, and the qnx-build container only mounts \$HOME."

dest="$HOME/qnxprojects/$name"
if ! qnx_home_rel "$dest" >/dev/null; then
  qnx_die "Refusing to create $dest because it is not under \$HOME. The qnx-build container bind-mounts your home directory and has no /Users tree, so qcc would not see the project."
fi
if [[ -e "$dest" ]]; then
  qnx_die "$dest already exists. This script does not replace it. Pick another NAME."
fi

mkdir -p "$HOME/qnxprojects"
home_phys="$(cd "$HOME" && pwd -P)"
parent_phys="$(cd "$HOME/qnxprojects" && pwd -P)"
case "$parent_phys" in
  "$home_phys"|"$home_phys"/*) ;;
  *)
    qnx_die "\$HOME/qnxprojects resolves outside \$HOME ($parent_phys). The container only mounts \$HOME, so the project would be invisible to qcc."
    ;;
esac

mkdir -p "$dest/.vscode"

cat >"$dest/Makefile" <<EOF
# QNX SDP 8.0, target aarch64le.
# qcc is on PATH only inside the qnx-build container.
# From the clone: ./scripts/run-on-qnx.sh ~/qnxprojects/$name
CC := qcc
QCC_SPEC := gcc_ntoaarch64le
TARGET := $name

.PHONY: all clean

all: \$(TARGET)

\$(TARGET): main.c
	\$(CC) -V\$(QCC_SPEC) -Wall -o \$(TARGET) main.c

clean:
	rm -f \$(TARGET)
EOF

cat >"$dest/main.c" <<EOF
#include <stdio.h>

int main(void)
{
    printf("hello from $name\\n");
    return 0;
}
EOF

# ${env:HOME} and ${workspaceFolder} are VS Code variables, not shell variables.
cat >"$dest/.vscode/tasks.json" <<EOF
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Build and run on QNX",
            "type": "shell",
            "command": "\${env:HOME}/$repo_rel/scripts/run-on-qnx.sh",
            "args": [
                "\${workspaceFolder}"
            ],
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "problemMatcher": [
                "\$gcc"
            ]
        }
    ]
}
EOF

echo "Created $dest"
echo "  $dest/Makefile"
echo "  $dest/main.c"
echo "  $dest/.vscode/tasks.json"
