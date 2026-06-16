# Dograh debugging — a method, not a lookup table

Diagnose by reading the **source of truth for what's wrong** — the container **logs**,
`docker compose ps`, and the **compose file** (services, dependency order, ports) — and
reasoning from there. This file is the method plus a few non-obvious gotchas; it does not
restate ports, env vars, or exact error strings (read those from the logs, the compose
file, and the environment-variables doc).

On a POSIX shell, `scripts/doctor.sh` runs the read-only pass for you. On Windows
PowerShell, do it by hand — `docker` and `curl` are cross-platform; use PowerShell
equivalents only for the port/disk checks.

First **orient** (SKILL.md Step 0): the OS; *where Dograh runs* (run the checks on the
server for a remote install); and whether it's a **deploy** or a **dev** setup — in dev
the API/UI run as native processes (different ports, infra in a separate compose file),
so `docker compose ps` won't show the app at all.

## Method (read-only first; one change at a time)

1. **Prerequisites** — is Docker installed and the daemon up? (Skip if the user runs
   fully native against external services.)
2. **State** — `docker compose ps`. What isn't running or healthy?
3. **Reason about dependencies** — services come up in an order (the compose `depends_on`
   chain): the UI needs the API, the API needs its datastores. **Fix the lowest broken
   layer first** — a red top layer is usually a red layer beneath it.
4. **Read the logs** — `docker compose logs` for the failing service. *This is the source
   of truth for the actual error.* Don't guess from symptoms; read the message and fix its
   root cause (a missing required env var, an unreachable datastore, a failed migration, a
   port clash, a wrong-architecture image — the log tells you which).
5. **Probe the endpoints** — the health endpoint and the UI (paths/ports per the compose
   file; a remote install serves over HTTPS through the proxy, not the raw app port). **A
   bare port answering is not proof this stack is up** — if `docker compose ps` shows no
   running containers for the project but the port responds, that's a *different* service
   on it. Trust container state over a port.
6. **Then**, as the logs direct, check port conflicts, disk/memory, and `.env`
   completeness.

After each change, re-run `doctor.sh` (or re-check by hand) before making the next one.

## Non-obvious gotchas (you wouldn't catch these at a glance)

- A **one-shot init/config container exiting 0 is success**, not a crash — services that
  depend on it only start *after* it completes; only a non-zero exit is a problem.
- **Some values are baked into the data volume on first init** (notably the DB password);
  editing them in `.env` afterward causes auth failures. Revert to the original value or
  re-key inside the running service — wiping the volume to "fix" it destroys all data.
- **Remote "loads but the call has no audio"** is almost always WebRTC/TURN ports closed
  in the **cloud** firewall (not just the host), or TURN not actually in the media path.
  The deployment docs describe the relay-only diagnostic toggle to prove it.
- **Dev confusion:** the app runs natively on dev ports and won't appear in
  `docker compose ps`; check the native processes and the dev infra compose separately.

## Safe resets (least → most destructive)

Restart a service → recreate it → `down` (keeps data) → **`down -v`, which deletes the
database and recordings (irreversible — confirm first)**. Never reach for the destructive
end just to "try something."

## Read more

Find the troubleshooting, deployment, or contributor page from the docs index
(`https://docs.dograh.com/llms.txt`) and read the specific one. The compose file and the
logs are the ultimate source of truth.
