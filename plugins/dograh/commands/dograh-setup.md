---
description: Set up (or repair) a Dograh self-hosted deployment via the dograh-setup skill — orient, pick deploy-vs-develop and fresh-vs-reuse, drive Dograh's own setup scripts, and verify with doctor.sh.
argument-hint: "[deploy|develop|local|remote] (optional)"
---

Use the **dograh-setup** skill to stand up Dograh (or repair a half-finished setup).

Requested target (may be empty): $ARGUMENTS

1. **Orient first** (SKILL.md Step 0): detect the OS/shell and what's installed, and
   confirm what the user wants — deploy vs develop, local vs remote, and whether to spin
   up fresh backing services or reuse ones they already run. Ask if it's unclear.
2. **Capture the starting state** (read-only):
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/dograh-setup/scripts/doctor.sh"`
3. **Pick the path and read its source** — `references/paths.md` says which doc/script to
   read. Read each setup script before running it, run it non-interactively with the
   answers preset as env vars, and start the stack detached.
4. **Verify** by re-running `doctor.sh` until it's green before telling the user it's ready.

When anything fails, don't guess — read the logs and follow the method in
`references/debug.md`.
