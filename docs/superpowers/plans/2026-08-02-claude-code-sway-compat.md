# Claude Code / Sway Session Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Confirm the root cause of Claude Code commands landing in a stray second sway session is fully closed by the session-manager plan, and add a regression guard so it can't silently come back.

**Architecture:** No new mechanism. This plan depends on `docs/superpowers/plans/2026-08-02-session-manager.md` having already been executed (specifically its Task 2, which deletes the `.zshrc` tty1 hack). It adds one automated regression check and a manual verification pass.

**Tech Stack:** POSIX shell / grep.

## Global Constraints

- This plan must run *after* `2026-08-02-session-manager.md` — it verifies that plan's effect, it doesn't duplicate it.
- No new autostart mechanism may be introduced anywhere in the repo as a side effect of this plan.

Spec reference: `docs/superpowers/specs/2026-08-02-claude-code-sway-compat-design.md`

---

### Task 1: Add a regression guard against reintroducing a sway autostart hook

**Files:**
- Create: `sway/scripts/test-no-autostart-hook.sh`

**Interfaces:**
- Consumes: the repo tree (greps `zsh/` for `exec sway`).
- Produces: a pass/fail check that can be re-run any time a future change touches `zsh/.zshrc`, to catch a reintroduced autostart hook before it ships.

- [ ] **Step 1: Write the check**

Create `sway/scripts/test-no-autostart-hook.sh`:

```sh
#!/bin/sh
set -e

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)

if grep -rn "exec sway" "$REPO_ROOT/zsh/"; then
    echo "FAIL: found an 'exec sway' autostart hook in zsh/ — sway must only be started by greetd (see docs/superpowers/specs/2026-08-02-session-manager-design.md)"
    exit 1
fi

echo "PASS"
```

```bash
chmod +x sway/scripts/test-no-autostart-hook.sh
```

- [ ] **Step 2: Run it**

Run: `./sway/scripts/test-no-autostart-hook.sh`
Expected: `PASS` (the session-manager plan already removed the hook — if this fails, stop and re-check that plan's Task 2 was actually applied before continuing).

- [ ] **Step 3: Commit**

```bash
git add sway/scripts/test-no-autostart-hook.sh
git commit -m "Add regression guard against reintroducing a sway autostart hook"
```

---

### Task 2: Manual on-target verification

No further automated test is possible — this requires Claude Code actually running inside a live sway session on the target server.

**Steps:**

- [ ] With the session-manager plan fully deployed and the server rebooted, open an alacritty terminal in sway and start Claude Code in it.
- [ ] From within that Claude Code session, run `pgrep -c sway`; expect exactly `1`.
- [ ] From within that Claude Code session, run `swaymsg -t get_tree` and confirm the reported windows/workspaces match what's actually visible on screen.
- [ ] Have Claude Code run a visible action (e.g. open a new window via `swaymsg exec alacritty`) and confirm it appears on the physical display, not silently in an orphaned session.

No commit for this task — verification only.
