#!/bin/sh
set -e

FILE="$(cd "$(dirname "$0")" && pwd)/config.toml"

check() {
    grep -qF "$1" "$FILE" || { echo "FAIL: missing line: $1"; exit 1; }
}

check 'vt = 1'
check 'command = "tuigreet --cmd sway"'
check 'user = "greeter"'

echo "PASS"
