#!/bin/sh
set -e

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export HOME="$TMPDIR"
mkdir -p "$HOME/.config/sway"

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/swaymsg" <<'EOF'
#!/bin/sh
echo "$@" >> "$SWAYMSG_LOG"
EOF
chmod +x "$TMPDIR/bin/swaymsg"
export PATH="$TMPDIR/bin:$PATH"
export SWAYMSG_LOG="$TMPDIR/swaymsg.log"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TOGGLE="$SCRIPT_DIR/toggle-layout.sh"
STATE="$HOME/.config/sway/kb-layout.conf"

# No state file yet -> defaults to fr -> first toggle switches to us
"$TOGGLE"
state=$(cat "$STATE")
[ "$state" = "input type:keyboard xkb_layout us" ] || { echo "FAIL: expected us, got: $state"; exit 1; }
grep -q "input type:keyboard xkb_layout us" "$SWAYMSG_LOG" || { echo "FAIL: swaymsg not called with us"; exit 1; }

# Second toggle: us -> fr
"$TOGGLE"
state=$(cat "$STATE")
[ "$state" = "input type:keyboard xkb_layout fr" ] || { echo "FAIL: expected fr, got: $state"; exit 1; }

# Corrupt state file -> falls back to treating current as fr -> switches to us
echo "garbage" > "$STATE"
"$TOGGLE"
state=$(cat "$STATE")
[ "$state" = "input type:keyboard xkb_layout us" ] || { echo "FAIL: expected us after corrupt state, got: $state"; exit 1; }

echo "PASS"
