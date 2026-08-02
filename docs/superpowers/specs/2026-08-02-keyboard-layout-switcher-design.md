# AZERTY / QWERTY Layout Switcher

## Context

`sway/config` currently hardcodes `input * { xkb_layout fr }`, and the
workspace-switching binds use `bindsym --to-code` against French AZERTY
symbol names (`ampersand`, `eacute`, `quotedbl`, …) for keys 1–10:

```
bindsym --to-code {
    $mod+ampersand workspace 1
    $mod+eacute workspace 2
    ...
}
```

`--to-code` resolves each keysym to a physical keycode at config-parse time,
under whatever layout is active then. If `xkb_layout` changes to `us`, these
symbols either don't exist in that layout or resolve to different physical
keys, breaking workspace switching. Plain single-letter binds elsewhere
(`$mod+a`, `$mod+q`, etc.) are keysym-based without `--to-code` and already
follow the active layout correctly — they are not part of this problem.

## Goal

A simple, keyboard-driven way to toggle between French AZERTY and US QWERTY
that keeps workspace-switching shortcuts working in both layouts, with no
manual keybind maintenance per layout.

## Design

### Approaches considered

- **Physical-position binding (`bindcode`) — chosen.** Bind workspace
  switching to the physical top-row keycodes (XKB keycodes 10–19) instead of
  any keysym. `bindcode` matches the key that was pressed, not the character
  the active layout maps it to — so these binds never need to change when
  `xkb_layout` changes, in either direction.
- **Parallel `fr.conf`/`us.conf` snippets — rejected.** Keep keysym-style
  binds but maintain two versions of the workspace block, swapped via a
  symlink and `swaymsg reload` on toggle. Rejected: more moving parts (two
  files to keep in sync, a visible reload) for a problem `bindcode` removes
  outright.
- **Runtime binding regeneration from a template — rejected.** A script that
  looks up the correct keysym names per layout and regenerates the block.
  Rejected as unnecessary complexity once `bindcode` makes regeneration
  unneeded.

### Components

- **`sway/config`** — rewrite the workspace-switch block to use `bindcode`
  for keys 1–10 (physical top row) instead of French symbol names. Replace
  the hardcoded `input * { xkb_layout fr }` with
  `include ./kb-layout.conf`. Add `bindsym $mod+F1 exec
  ~/.config/sway/scripts/toggle-layout.sh`.
- **`sway/kb-layout.conf`** — new, gitignored, one-line generated file:
  `input type:keyboard xkb_layout <fr|us>`. Not tracked in git since it's
  runtime state, not configuration; `install.sh` seeds it with `fr` on first
  install.
- **`sway/scripts/toggle-layout.sh`** — new script:
  1. Reads the current layout out of `sway/kb-layout.conf`.
  2. Flips `fr` ↔ `us`.
  3. Applies live: `swaymsg input type:keyboard xkb_layout <new>`.
  4. Rewrites `sway/kb-layout.conf` with the new value, so it persists
     across restarts (sway reads it via `include` on next startup).

### Data flow

`$mod+F1` → `toggle-layout.sh` → live layout switch via `swaymsg` (no reload
needed) + persisted state file for next boot.

### Error handling

The script is a strict two-way toggle — it reads one of exactly two known
strings. If the state file is missing, unreadable, or contains anything
else, the script defaults to `fr` (matches current behavior) and recreates
the file with that value.

### Out of scope

Support for more than two layouts (fr/us) — explicitly deferred; the design
doesn't preclude adding a cycle-through-N-layouts mode later, but nothing
here is built for it.

## Testing

- Press `$mod+F1`: confirm typed characters switch layout immediately.
- Confirm workspace-switch keys 1–10 work correctly in both layouts.
- Restart sway (or reboot): confirm the last-selected layout persisted.
