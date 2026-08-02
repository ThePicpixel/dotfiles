#!/bin/sh
set -e

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)

if grep -rn "exec sway" "$REPO_ROOT/zsh/"; then
    echo "FAIL: found an 'exec sway' autostart hook in zsh/ — sway must only be started by greetd (see docs/superpowers/specs/2026-08-02-session-manager-design.md)"
    exit 1
fi

echo "PASS"
