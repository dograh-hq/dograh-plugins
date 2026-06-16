# Dograh plugins for Claude Code and Codex

Official plugins for the [Dograh](https://dograh.com) open-source voice-AI platform.

Supports Claude Code and Codex.

## Install

In Codex:

```text
codex plugin marketplace add .
codex plugin add dograh@dograh
```

Start a new thread afterwards so the skill loads.

In Claude Code:

```text
/plugin marketplace add dograh-hq/dograh-plugins
/plugin install dograh@dograh
```

Start a new session afterwards so the skill and commands load.

## What's inside

### `dograh` plugin

Helps you **set up, run, and troubleshoot** a self-hosted Dograh deployment.

- **Skill `dograh-setup`** — triggers when you ask to install, run, develop on, or
  debug Dograh. It orients first (your OS, what's installed, deploy-vs-develop,
  fresh-vs-reuse services), then reads and drives Dograh's own setup scripts and docs
  rather than hard-coding steps — so it stays current as Dograh changes.
- **Script `doctor.sh`** — one-shot diagnosis of a deployment: prerequisites,
  container/service state, ports, the `/api/v1/health` endpoint, the UI, and
  `.env` sanity. Prints `[OK] / [WARN] / [FAIL]` with remediation hints and a
  non-zero exit code when something is wrong.
- **Commands (Claude Code)** — `/dograh-setup` and `/dograh-doctor` as explicit entry points. Codex uses the `dograh-setup` skill and starter prompts instead.

## Scope

v1 covers **setup and troubleshooting** — deploying Dograh (local or remote, with Docker
or your own existing services) and the developer setup paths, plus diagnosing a broken
stack. Telephony configuration and call load-testing are planned for later versions.

## Links

- Docs: https://docs.dograh.com
- Main repo: https://github.com/dograh-hq/dograh
