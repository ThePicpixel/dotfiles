# Session Manager (greetd + tuigreet)

## Context

These dotfiles are installed on a minimal openSUSE Tumbleweed server running
sway as the only graphical environment. There is currently no display/session
manager: `zsh/.zshrc` contains a hack that execs sway when a login shell
detects it's on `/dev/tty1` with no `$DISPLAY` set:

```sh
if [ -z $DISPLAY ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec sway
fi
```

This is fragile — it can re-fire and spawn a second `sway` process (this is
the confirmed root cause of the Claude Code session-mismatch problem, see
[2026-08-02-claude-code-sway-compat-design.md](2026-08-02-claude-code-sway-compat-design.md)) —
and it produces a session with no real PAM login and no guarantee of a
correct `XDG_SESSION_TYPE`.

## Goal

Replace the tty1/`.zshrc` hack with `greetd`, a minimal Wayland-native login
daemon, paired with `tuigreet` (TUI greeter, no GTK/X11 dependencies) as the
session manager for the server. Login prompts for username/password (no
auto-login) and execs sway directly on success.

## Design

### Components

- **`/etc/greetd/config.toml`** — new file, written by `install.sh` (needs
  root ownership, so it is not repo-symlinked like the rest of the dotfiles).
  Configures `command = "tuigreet --cmd sway"` so a successful login execs
  sway as the authenticated user's session.
- **`install.sh`**:
  - Add `greetd tuigreet` to the package install list.
  - Write `/etc/greetd/config.toml`.
  - `systemctl enable greetd`.
  - Disable/mask any pre-existing display manager (e.g. `gdm`) so there is
    exactly one DM enabled — greetd and another DM both owning the console
    would conflict.
- **`zsh/.zshrc`** — delete the tty1/`exec sway` block entirely. Sway is now
  only ever started by greetd.

### Data flow

Boot → systemd starts `greetd.service` on the configured VT → tuigreet
renders a login prompt → PAM authenticates → greetd execs `sway` as the
user's session, replacing the greeter process on that VT.

### Error handling

- Failed auth: tuigreet re-prompts automatically; no custom scripting needed.
- Sway crash: greetd's default behavior returns to the greeter rather than
  dropping to a dead shell.

### Out of scope

- Auto-login was considered and explicitly rejected in favor of a real
  username/password prompt (server security posture).
- Graphical greeters (gtkgreet) and other DMs (LightDM, SDDM) were considered
  and rejected — tuigreet avoids pulling GTK/Qt dependencies onto a minimal
  server whose only GUI is sway itself.

## Testing

After install, reboot and confirm:
- Exactly one `sway` process in `ps aux`.
- `loginctl` shows a session with `Type=wayland` on the correct seat.
- Login prompt requires username/password (no auto-login).
