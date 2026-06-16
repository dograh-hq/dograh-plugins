---
description: Diagnose a Dograh deployment via the dograh-setup skill — run doctor.sh, read the report, and fix the top issue (failing health check, unhealthy/exited container, port conflict, etc.).
argument-hint: "[path to deployment dir] (optional)"
---

Diagnose the Dograh deployment. Target directory, if given (otherwise the current one): $ARGUMENTS

1. Run the read-only diagnostic (add `--dir <path>` if a directory was given, or
   `--mode dev` for a contributor/native setup):
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/dograh-setup/scripts/doctor.sh"`
2. Read the `[OK] / [WARN] / [FAIL]` report and start with the first `[FAIL]`.
3. Follow the method in the **dograh-setup** skill's `references/debug.md` — read the
   failing service's logs (the source of truth for the error) before changing anything.
4. Apply one change at a time, then re-run `doctor.sh` to confirm progress.

Never run a destructive command that deletes the data volume (e.g. `down -v` — it wipes
the database and recordings) without explicit confirmation from the user.
