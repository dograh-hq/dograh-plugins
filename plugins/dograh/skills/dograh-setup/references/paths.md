# Dograh paths — which source to read for each branch

After orienting (SKILL.md Step 0), pick the branch, then **read Dograh's own source for
it and do what it says** — don't follow commands from memory; they drift. This file only
points you at the right source.

## Decision tree

```
Deploy (run it) ── Local ── normal ........... local quick-start
   or            │        └ no call audio .... local + TURN
Develop (code) ──┤        Remote server ...... remote (HTTPS — run ON the server)
                 └ Containerized .............. devcontainer
                   Native ...................... host-managed
```

Ask which branch when it isn't obvious, and settle **fresh vs reuse** for the backing
services (SKILL.md Step 0.3) — that's a separate choice from how the app is run.

## Where to read each branch

- **Deploy** (local / local+TURN / remote) → the **deployment docs** (find them from the
  docs index, `https://docs.dograh.com/llms.txt`). They give the download-and-run
  command, the right script, the start command, the access URL, and — for remote — the
  firewall ports. Remote is HTTPS served on the box: run setup *and every check* on the
  server, not your laptop.
- **Develop** (devcontainer / host-managed) → the **contributor setup docs**. Both need a
  git checkout of the user's fork first; the devcontainer path is containerized, the
  host-managed path runs the app natively with its backing services in Docker (or
  external).
- **Unsure which script does what** → `scripts/AGENTS.md` in the repo catalogues the
  setup and "start" scripts and how they differ. Read it instead of guessing.

## Running the scripts (non-interactive)

The setup scripts are interactive, and some run `docker compose up` in the foreground.
**Read the script before running it** — it's short and tells you its prompts, the env
vars that bypass them, and whether it starts the stack. Then preset those env vars from
the user's Step-0 answers, run it with no prompts, and **start the stack detached**
yourself. Verify with `scripts/doctor.sh` rather than tailing foreground logs.

## Dependencies — fresh vs reuse

Docker brings the backing services up fresh; that's the easy default, not a requirement.
If the user already runs the database (it must support the **vector extension** Dograh's
migrations enable), the cache, or object storage — or a managed equivalent — point Dograh
at them via env vars instead. The **environment-variables doc** is the authoritative list
of those vars (connection strings, the storage toggle, the required secret); read it
rather than guessing. Rule of thumb: nothing running and wants it simple → Docker;
already has the services → reuse.

## After setup & beyond

Connecting the Dograh MCP, configuring inference providers, upgrading, scaling, a custom
domain — each has its own docs page. Find it from the `llms.txt` index and read that one
page. Don't re-run the initial setup script to "fix" or upgrade an existing install — the
docs point to the proper update path.
