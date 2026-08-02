# Claude Code / Sway Session Compatibility

## Context

Reported symptom: commands run by Claude Code (from inside an alacritty
terminal running under sway) sometimes take effect in — or are read back
from — a different sway session than the one visible on screen, observed
concretely as multiple `sway` processes in `ps aux`.

## Root cause

Confirmed: this is caused by the `.zshrc` tty1 auto-exec hack (see
[2026-08-02-session-manager-design.md](2026-08-02-session-manager-design.md)),
which re-fires and spawns a second `sway` process under certain shell
conditions. Once that block is removed and greetd becomes the sole starter
of sway, there is no remaining mechanism in these dotfiles that can start a
second sway instance.

## Goal

No new mechanism is being built here — this spec exists to document the
causal link (so it isn't re-investigated as a mystery later) and to pin down
an explicit regression check, since "exactly one sway process" is a property
that could silently break again if a future change reintroduces some other
autostart path.

## Design

This feature is fully satisfied by implementing
[2026-08-02-session-manager-design.md](2026-08-02-session-manager-design.md).
No additional files or scripts are introduced.

## Testing

With Claude Code running inside an alacritty terminal under sway:
- `pgrep -c sway` reports `1`.
- A command Claude runs that reads session state (e.g. `swaymsg -t
  get_tree`) reflects the actual on-screen session — no discrepancy between
  what Claude observes and what's visible.
