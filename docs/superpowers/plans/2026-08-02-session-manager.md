# Session Manager (greetd + tuigreet) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fragile `.zshrc` tty1 auto-exec hack with `greetd` + `tuigreet` as a proper session manager that logs in via PAM and execs sway.

**Architecture:** `install.sh` gains steps to install `greetd`/`tuigreet`, deploy a repo-tracked `greetd/config.toml` to `/etc/greetd/config.toml`, ensure the `greeter` system user exists, enable the `greetd` service, and disable any conflicting display manager. `zsh/.zshrc` loses the tty1 hack entirely.

**Tech Stack:** POSIX shell (`install.sh`, zsh), TOML (`greetd/config.toml`), systemd, PAM (via greetd).

## Global Constraints

- Target is a minimal openSUSE Tumbleweed server — no GTK/Qt greeter, no desktop environment. Use `tuigreet` only.
- Exactly one display manager may be enabled at a time. If another DM (e.g. `gdm`) is present and enabled, disable it.
- No auto-login. tuigreet must prompt for username/password.
- Sway must only ever be started by greetd after this change — no other autostart path may remain.

Spec reference: `docs/superpowers/specs/2026-08-02-session-manager-design.md`

---

### Task 1: Add the greetd config template and its content test

**Files:**
- Create: `greetd/config.toml`
- Test: `greetd/test-config.sh`

**Interfaces:**
- Produces: `greetd/config.toml` — a TOML file with a `[terminal]` table (`vt = 1`) and a `[default_session]` table (`command = "tuigreet --cmd sway"`, `user = "greeter"`). Task 3 copies this file to `/etc/greetd/config.toml` verbatim.

- [ ] **Step 1: Write the failing test**

Create `greetd/test-config.sh`:

```sh
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
```

```bash
chmod +x greetd/test-config.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./greetd/test-config.sh`
Expected: FAIL — `greetd/config.toml` does not exist yet (grep errors on missing file).

- [ ] **Step 3: Write the config file**

Create `greetd/config.toml`:

```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd sway"
user = "greeter"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./greetd/test-config.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add greetd/config.toml greetd/test-config.sh
git commit -m "Add greetd+tuigreet config template"
```

---

### Task 2: Remove the tty1 auto-exec hack from .zshrc

**Files:**
- Modify: `zsh/.zshrc`

**Interfaces:**
- Consumes: none.
- Produces: `zsh/.zshrc` with no reference to `exec sway` — later tasks (and the compat plan) rely on this being fully gone.

- [ ] **Step 1: Confirm current content (anchor check)**

Run: `grep -n "exec sway" zsh/.zshrc`
Expected output (line number may differ if the file has changed since this plan was written — if so, treat the matched line as the anchor instead of the number below):

```
78:	          exec sway
```

- [ ] **Step 2: Remove the hack**

Delete this block from `zsh/.zshrc` (currently lines 77-79):

```sh
if [ -z $DISPLAY ] && [ "$(tty)" = "/dev/tty1" ]; then
	          exec sway
fi
```

Leave the surrounding blank lines as a single blank line separator (don't leave a double-blank gap).

- [ ] **Step 3: Verify removal and shell syntax**

Run: `grep -c "exec sway" zsh/.zshrc || true`
Expected: `0`

Run: `zsh -n zsh/.zshrc`
Expected: no output, exit code `0` (syntax-only check, does not execute the file).

- [ ] **Step 4: Commit**

```bash
git add zsh/.zshrc
git commit -m "Remove tty1 auto-exec sway hack now that greetd owns session startup"
```

---

### Task 3: Wire greetd into install.sh

**Files:**
- Modify: `install.sh`

**Interfaces:**
- Consumes: `greetd/config.toml` (Task 1).
- Produces: a running system where `greetd.service` is enabled, `/etc/greetd/config.toml` matches the repo template, and no conflicting DM is enabled. Nothing later in this plan depends on this programmatically — it's the deployment step.

- [ ] **Step 1: Add packages to the install list**

In `install.sh`, find this block (currently lines 18-21):

```sh
log "Installing wayland graphical environment"
install\
    rofi thunar sway brightnessctl swaylock lxsession lxappearance\
    alacritty i3status
```

Change it to:

```sh
log "Installing wayland graphical environment"
install\
    rofi thunar sway brightnessctl swaylock lxsession lxappearance\
    alacritty i3status greetd tuigreet
```

- [ ] **Step 2: Add greetd setup after the config symlinks**

Find this block (currently lines 85-90):

```sh
ln -s ~/Documents/dotfiles/alacritty ~/.config
ln -s ~/Documents/dotfiles/i3status ~/.config
ln -s ~/Documents/dotfiles/rofi ~/.config
ln -s ~/Documents/dotfiles/sway ~/.config
ln -s ~/Documents/dotfiles/git/.gitconfig ~/.gitconfig
ln -s ~/Documents/dotfiles/zsh/.zshrc ~/.zshrc
```

Immediately after it (before the `log "Configure subuids..."` section), insert:

```sh
log "Configuring greetd session manager"
if ! id greeter >/dev/null 2>&1; then
    log "Creating greeter system user for greetd"
    sudo useradd -M -G video -s /usr/sbin/nologin greeter
fi
sudo mkdir -p /etc/greetd
sudo cp ~/Documents/dotfiles/greetd/config.toml /etc/greetd/config.toml
sudo systemctl enable greetd

if systemctl list-unit-files | grep -q '^gdm.service'; then
    log "Disabling gdm in favor of greetd"
    sudo systemctl disable --now gdm.service
fi
```

- [ ] **Step 3: Verify the edits**

Run: `bash -n install.sh`
Expected: no output, exit code `0` (syntax-only check).

Run:
```bash
grep -q "greetd tuigreet" install.sh && \
grep -q "systemctl enable greetd" install.sh && \
grep -q "cp ~/Documents/dotfiles/greetd/config.toml /etc/greetd/config.toml" install.sh && \
echo PASS
```
Expected: `PASS`

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "Install and enable greetd+tuigreet, disable conflicting DM"
```

---

### Task 4: Manual on-target verification

This task has no automated test — it requires an actual openSUSE Tumbleweed server install and a reboot, which isn't available in a repo checkout.

**Steps (run on the target server after `install.sh` has been run there):**

- [ ] Reboot the server.
- [ ] Confirm the login prompt is tuigreet and requires a username/password (no auto-login).
- [ ] Log in and run `ps aux | grep '[s]way'` — expect exactly one `sway` process.
- [ ] Run `loginctl` and confirm your session shows `Type=wayland` on `seat0`.
- [ ] Log out and back in a second time; confirm the same holds (no leaked/duplicate sway processes across a second login).

No commit for this task — it's verification only. If any check fails, open a follow-up task rather than patching ad hoc.
