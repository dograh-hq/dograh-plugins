---
name: dograh-setup
description: >-
  Set up, run, develop, and troubleshoot the Dograh voice-AI platform on any OS
  (macOS, Linux, Windows/WSL). Use whenever the user wants to install, deploy,
  run, or contribute to Dograh — or when a Dograh stack is broken: the UI won't
  load, the API health check (/api/v1/health) is failing, containers are
  unhealthy/restarting, ports conflict, Docker is missing, or a call has no audio
  (WebRTC/TURN). Covers the deploy paths (local quick, local+TURN, remote HTTPS)
  and the developer paths (devcontainer, host-managed). It orients first —
  detects your OS and what's installed, asks deploy-vs-develop — then drives
  Dograh's own scripts and docs instead of hard-coding steps. Trigger on "set up
  dograh", "install dograh", "dograh dev setup", "dograh won't start", or
  "dograh health check failing".
---

# Dograh: set up, develop & troubleshoot

Help the user stand up, develop on, or debug a self-hosted **Dograh** deployment — on
macOS, Linux, or Windows. Dograh is a small set of backing services plus an API and a
UI, run together most simply with Docker (though the services can also be external or
native).

**Core principle: orient, then read the source — don't memorize it here.** The exact
scripts, commands, env vars, ports, and flows live in Dograh's own repo and docs, and
they change over time. This skill carries *how to reason* and *where to read* — it
deliberately does **not** restate those specifics, because a copy here would drift and
bloat your context. So: detect the situation, confirm what the user wants, then read the
authoritative source for the chosen path and do what it says.

## Step 0 — Orient (always first)

**1. Where am I, and what's available?** Detect the OS and shell — don't assume bash;
it may be Windows PowerShell or WSL2/Git-Bash. Check which tools actually exist before
relying on them (`docker`, `docker compose`, `curl`, `git`; plus `python`/`node` for
dev). Establish **where Dograh runs** — this machine, or a remote server you'll SSH into
and run everything *on*.

**2. What does the user want?** Ask when it isn't clear:

```
Deploy Dograh (run it) or Develop it (work on its code)?
  Deploy  → Local machine or remote server?
  Develop → Containerized or native?
Backing services (database / cache / object storage):
  spin up fresh — or reuse ones the user already runs?
```

**3. Docker is optional — ask, don't assume.** Docker Compose is the convenient default:
it brings up fresh backing services and the app in one step. But it is **not** required.
If the user already runs the database, cache, or object storage — or a managed
equivalent (Supabase, a managed Redis, S3) — Dograh can point at those via env vars, and
the app can run natively. The hard requirements are the *services*, not Docker. Read the
environment-variables doc (see Sources) for the exact wiring, and **ask** fresh-vs-reuse
rather than silently installing fresh infra or forcing Docker. (One buried gotcha: the
database must support the vector extension Dograh's migrations enable — a plain Postgres
without it will fail to migrate.)

## Act — read the source for the chosen path, then drive it

Don't follow step lists from memory — read Dograh's current source and do what it says.
`references/paths.md` maps each branch to *which source to read*. In short:

- **The authoritative steps** for any path live in Dograh's docs (start at the index
  `https://docs.dograh.com/llms.txt`, open the one relevant deployment or contributor
  page, and fetch *just that page* — never the whole corpus) and in the repo's
  `scripts/AGENTS.md`, which catalogues the setup scripts. Read those to learn which
  script/command to run.
- **Before running any setup script, read it.** They're short shell scripts (you've just
  downloaded one, or can fetch it from the repo). Reading it shows its prompts, the env
  vars that bypass them, and whether it starts the stack — all of which you need.
- **Env vars, ports, and services** are defined in the environment-variables doc and the
  `docker-compose` file — read those instead of assuming values.
- Adapt to the detected OS (Dograh ships PowerShell variants of the user-facing scripts;
  bash-only ones run under WSL2).

## Running scripts as an agent (non-interactive)

The setup scripts prompt for input, and some end by running `docker compose up` in the
foreground — either would stall a non-interactive shell. They're non-interactive-*safe*
(no TTY → they fall back to defaults instead of hanging), but to get the config the user
actually wants:

- **Read the script first** to learn its prompts and the env vars that preset them, then
  run it with those env vars set from the user's Step-0 answers — no prompts needed.
- **Start the stack yourself, detached** (background it / use the detached form) so a
  foreground `up` can't block you. Then verify with `doctor.sh` instead of tailing logs.

## Diagnose

Read `references/debug.md` — a *method*, not a lookup table. It tells you what to inspect
(read-only), in what order, and how to reason; the **logs and the compose file are the
source of truth** for what's actually wrong. On a POSIX shell, `scripts/doctor.sh` runs
the read-only pass for you; on Windows PowerShell, follow the method by hand.

## Guardrails

- **Never run a destructive command** — anything that deletes volumes/data (e.g. a
  `down -v`) — without explicit confirmation; it erases the database and recordings.
- **Some values are write-once** (e.g. the DB password is baked into the data volume on
  first init); the compose file flags these — changing them later breaks things.
- **Don't fabricate config or invent flags** — regenerate secrets the way the scripts do,
  or re-run the script. One change at a time, then re-check.

## After every run — offer feedback (consent required)

When a run wraps up (setup finished, or a debug session resolved or ended), offer to
send a short note back so the skill improves:

1. **Ask** — "Want to share quick feedback on how that went? (optional)". If they
   decline, send nothing and stop.
2. **Compose a one-line comment** = light context + their words, e.g.
   `[deploy-remote | success | macOS] doctor.sh caught the missing OSS_JWT_SECRET fast — smooth.`
   Context is: the path taken (deploy-local / deploy-remote / dev-devcontainer /
   dev-host-managed), the outcome (success / partial / failed), and the OS — then the
   user's verbatim words.
3. **Show the user the exact text and confirm.** Sending appends it to a Google Sheet
   and emails the Dograh team, so consent must be explicit.
4. **On an explicit yes, send it:**
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/dograh-setup/scripts/send_feedback.sh" "<the comment>"`
   On Windows PowerShell, POST the same JSON instead:
   `Invoke-RestMethod -Method Post -ContentType 'application/json' -Body '{"comments":"<text>"}' -Uri <webhook>`.
5. **Never include** secrets, tokens, full `.env` values, IPs, or credentials — only the
   path, outcome, OS, and the user's words.

## Sources of truth (read these; don't restate them)

- **Repo** — `https://github.com/dograh-hq/dograh`, especially `scripts/AGENTS.md` (the
  setup-script catalogue) and the `docker-compose` files (services, ports, profiles).
- **Docs** — `https://docs.dograh.com`; use `…/llms.txt` (a small index) to find the one
  page you need, then fetch just that page. The environment-variables page is the
  authoritative config list.
- **After setup** — the docs' MCP page (connect the Dograh MCP for agent authoring) and
  the inference-providers page (add LLM/STT/TTS keys so an agent can actually talk).

## Reference map

- `references/paths.md` — the decision tree and *which source to read* per branch.
- `references/debug.md` — the diagnostic method.
- `scripts/doctor.sh` — read-only diagnostic accelerator (POSIX shells).
