# AZERTY/QWERTY Layout Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `$mod+F1` toggle between French AZERTY and US QWERTY that applies live and persists across restarts, without ever needing to touch workspace-switch keybindings again.

**Architecture:** `sway/config`'s workspace-switch bindings move from layout-dependent `bindsym --to-code` (French symbol names) to layout-independent `bindcode` (physical keycodes 10-19). `xkb_layout` moves out of `sway/config` into a small generated `sway/kb-layout.conf`, pulled in via `include`. A new `sway/scripts/toggle-layout.sh` flips the layout live via `swaymsg` and rewrites that file.

**Tech Stack:** POSIX shell, sway/i3-style config syntax, `swaymsg`.

## Global Constraints

- Exactly two layouts: `fr` and `us`. No N-layout cycling — that's explicitly out of scope.
- Workspace-switch bindings must use `bindcode` (physical position), never a keysym tied to a specific layout.
- Toggling must apply live via `swaymsg` — no `swaymsg reload`.
- The choice must persist across a sway restart/reboot.
- If the persisted state is missing or unrecognized, the script must fall back to treating current state as `fr` (matches today's hardcoded default).

Spec reference: `docs/superpowers/specs/2026-08-02-keyboard-layout-switcher-design.md`

---

### Task 1: Write and test `toggle-layout.sh`

**Files:**
- Create: `sway/scripts/toggle-layout.sh`
- Test: `sway/scripts/test-toggle-layout.sh`

**Interfaces:**
- Consumes: `$HOME/.config/sway/kb-layout.conf` (state file — read/written by this script; format is exactly one line, `input type:keyboard xkb_layout <fr|us>`).
- Produces: on each run, flips the layout and calls `swaymsg input type:keyboard xkb_layout <new>`, then overwrites the state file with the new one-line content. Task 2 relies on this exact state file format and path. Task 3's `sway/config` relies on this exact path via `include`.

- [ ] **Step 1: Write the failing test**

Create `sway/scripts/test-toggle-layout.sh`:

```sh
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
```

```bash
chmod +x sway/scripts/test-toggle-layout.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./sway/scripts/test-toggle-layout.sh`
Expected: FAIL — `toggle-layout.sh: No such file or directory` (script doesn't exist yet).

- [ ] **Step 3: Write the implementation**

Create `sway/scripts/toggle-layout.sh`:

```sh
#!/bin/sh
set -e

STATE_FILE="$HOME/.config/sway/kb-layout.conf"

current="fr"
if [ -f "$STATE_FILE" ]; then
    case "$(cat "$STATE_FILE")" in
        *xkb_layout\ us*) current="us" ;;
        *xkb_layout\ fr*) current="fr" ;;
        *) current="fr" ;;
    esac
fi

if [ "$current" = "fr" ]; then
    new="us"
else
    new="fr"
fi

swaymsg "input type:keyboard xkb_layout $new" >/dev/null
echo "input type:keyboard xkb_layout $new" > "$STATE_FILE"
```

```bash
chmod +x sway/scripts/toggle-layout.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./sway/scripts/test-toggle-layout.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add sway/scripts/toggle-layout.sh sway/scripts/test-toggle-layout.sh
git commit -m "Add live AZERTY/QWERTY toggle script with test"
```

---

### Task 2: Ignore and seed the runtime state file

**Files:**
- Modify: `.gitignore`
- Modify: `install.sh`

**Interfaces:**
- Consumes: the state file format from Task 1 (`input type:keyboard xkb_layout <fr|us>`).
- Produces: `.gitignore` entry for `sway/kb-layout.conf` (never committed — it's runtime state, not config), and an `install.sh` step that seeds it with `fr` on fresh installs so `sway/config`'s `include` (Task 3) never points at a missing file.

- [ ] **Step 1: Add the gitignore entry**

Append to `.gitignore`:

```
sway/kb-layout.conf
```

- [ ] **Step 2: Seed the file during install**

In `install.sh`, inside the `greetd` block added by the session-manager plan (or, if that plan hasn't run yet, immediately after the config symlink block that does `ln -s ~/Documents/dotfiles/sway ~/.config`), add:

```sh
log "Seeding default keyboard layout state"
if [ ! -f ~/Documents/dotfiles/sway/kb-layout.conf ]; then
    echo "input type:keyboard xkb_layout fr" > ~/Documents/dotfiles/sway/kb-layout.conf
fi
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -qxF "sway/kb-layout.conf" .gitignore && \
grep -q "Seeding default keyboard layout state" install.sh && \
bash -n install.sh && \
echo PASS
```
Expected: `PASS`

- [ ] **Step 4: Commit**

```bash
git add .gitignore install.sh
git commit -m "Ignore and seed the keyboard layout state file"
```

---

### Task 3: Rewire sway/config to use bindcode and the toggle

**Files:**
- Modify: `sway/config`

**Interfaces:**
- Consumes: `sway/scripts/toggle-layout.sh` (Task 1), `sway/kb-layout.conf` (Task 2, via `include`).
- Produces: workspace-switch keybindings that no longer reference any layout-specific symbol, and a `$mod+F1` binding wired to the toggle script.

- [ ] **Step 1: Replace the hardcoded input block**

Find (currently lines 121-125):

```
###
# Inputs
################################################################################
input * {
    xkb_layout fr
}
```

Replace with:

```
###
# Inputs
################################################################################
include ./kb-layout.conf
```

- [ ] **Step 2: Replace the workspace-switch bindings with bindcode**

Find the `bindsym --to-code { ... }` block (currently lines 81-102):

```
bindsym --to-code {
	$mod+ampersand workspace 1
	$mod+eacute workspace 2
	$mod+quotedbl workspace 3
	$mod+apostrophe workspace 4
	$mod+parenleft workspace 5
	$mod+minus workspace 6
	$mod+egrave workspace 7
	$mod+underscore workspace 8
	$mod+ccedilla workspace 9
	$mod+agrave workspace 10
	$mod+Shift+ampersand move container to workspace 1
	$mod+Shift+eacute move container to workspace 2
	$mod+Shift+quotedbl move container to workspace 3
	$mod+Shift+apostrophe move container to workspace 4
	$mod+Shift+parenleft move container to workspace 5
	$mod+Shift+egrave move container to workspace 6
	$mod+Shift+minus move container to workspace 7
	$mod+Shift+underscore move container to workspace 8
	$mod+Shift+ccedilla move container to workspace 9
	$mod+Shift+agrave move container to workspace 10
}
```

Replace with:

```
bindcode $mod+10 workspace $ws1
bindcode $mod+11 workspace $ws2
bindcode $mod+12 workspace $ws3
bindcode $mod+13 workspace $ws4
bindcode $mod+14 workspace $ws5
bindcode $mod+15 workspace $ws6
bindcode $mod+16 workspace $ws7
bindcode $mod+17 workspace $ws8
bindcode $mod+18 workspace $ws9
bindcode $mod+19 workspace 10
bindcode $mod+Shift+10 move container to workspace $ws1
bindcode $mod+Shift+11 move container to workspace $ws2
bindcode $mod+Shift+12 move container to workspace $ws3
bindcode $mod+Shift+13 move container to workspace $ws4
bindcode $mod+Shift+14 move container to workspace $ws5
bindcode $mod+Shift+15 move container to workspace $ws6
bindcode $mod+Shift+16 move container to workspace $ws7
bindcode $mod+Shift+17 move container to workspace $ws8
bindcode $mod+Shift+18 move container to workspace $ws9
bindcode $mod+Shift+19 move container to workspace 10
```

(Keycodes 10-19 are the physical top-row number keys 1-0, XKB keycode = evdev scancode + 8 — this mapping is the same on every PC keyboard regardless of the active layout.)

- [ ] **Step 3: Add the toggle keybinding**

In the "Program Launcher" section (near the other `bindsym $mod+...` exec lines, currently around line 11-17), add:

```
bindsym $mod+F1 exec ~/.config/sway/scripts/toggle-layout.sh
```

- [ ] **Step 4: Verify the edits**

Run:
```bash
grep -q "include ./kb-layout.conf" sway/config && \
grep -qc "bindcode \$mod+10 workspace" sway/config && \
grep -q "bindsym \$mod+F1 exec ~/.config/sway/scripts/toggle-layout.sh" sway/config && \
! grep -q "ampersand" sway/config && \
! grep -q "xkb_layout fr" sway/config && \
echo PASS
```
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add sway/config
git commit -m "Move workspace-switch binds to bindcode, wire mod+F1 to layout toggle"
```

---

### Task 4: Manual on-target verification

No automated test — requires a running sway session on the target server.

**Steps:**

- [ ] Log into sway; confirm `~/.config/sway/kb-layout.conf` exists with `input type:keyboard xkb_layout fr`.
- [ ] Press `$mod+F1`; type a character in a terminal and confirm it now matches the US QWERTY layout.
- [ ] Confirm `$mod+1` through `$mod+0` (physical top row) still switch workspaces 1-10 correctly under QWERTY.
- [ ] Press `$mod+F1` again to switch back to AZERTY; confirm typed characters match AZERTY and workspace switching still works.
- [ ] Restart sway (or reboot); confirm the layout in effect is whichever was last selected, not reset to `fr`.

No commit for this task — verification only.
