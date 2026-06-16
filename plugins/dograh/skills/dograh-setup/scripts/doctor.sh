#!/usr/bin/env bash
#
# doctor.sh — read-only diagnostics for a Dograh deployment (deploy or dev).
#
# Inspects prerequisites, finds a deployment if there is one, and reports
# container/service health, ports, the /api/v1/health endpoint, the UI, and
# .env sanity. It never starts, stops, or deletes anything.
#
# Usage: doctor.sh [--dir <dir>] [--mode dev|deploy] [--no-color]
# Exit:  0 = healthy, 1 = warnings only, 2 = failures.
#
# POSIX shells only (macOS / Linux / WSL2 / Git-Bash). On native Windows
# PowerShell, follow the checklist in references/debug.md instead. For a REMOTE
# deployment, run this ON THE SERVER — the API/UI live there, not on your laptop.

set -uo pipefail

DIR=""
USE_COLOR="auto"
FAILS=0
WARNS=0
MODE="local"
SERVER_IP=""
DOCKER_OK=1
DEPLOY_FOUND=0
RUNNING_COUNT=0
WANT_MODE=""
DEV=0

usage() {
  cat <<'USAGE'
Usage: doctor.sh [--dir <dir>] [--mode dev|deploy] [--no-color]

Read-only diagnosis of a Dograh deployment: prerequisites, container/service
health, ports, the /api/v1/health endpoint, the UI, and .env sanity.

  --dir <path>   Directory holding the compose file (default: current dir, or
                 ./dograh if that is where it lives).
  --mode <m>     dev | deploy. Default: auto (deploy, unless only a
                 docker-compose-local.yaml is present). Dev expects the UI on
                 :3000 and the API possibly running natively (not a container).
  --no-color     Disable ANSI colors.

POSIX shells only (macOS/Linux/WSL/Git-Bash). For a remote deployment, run it on
the server. Exit code: 0 = healthy, 1 = warnings only, 2 = failures.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="${2:-}"; shift 2 ;;
    --dir=*) DIR="${1#*=}"; shift ;;
    --mode) WANT_MODE="${2:-}"; shift 2 ;;
    --mode=*) WANT_MODE="${1#*=}"; shift ;;
    --no-color) USE_COLOR="no"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n\n' "$1"; usage; exit 2 ;;
  esac
done

if [ "$USE_COLOR" = "no" ] || [ ! -t 1 ]; then
  R=""; G=""; Y=""; B=""; NC=""
else
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; NC='\033[0m'
fi

ok()      { printf "  ${G}[ OK ]${NC} %s\n" "$1"; }
warn()    { printf "  ${Y}[WARN]${NC} %s\n" "$1"; WARNS=$((WARNS + 1)); }
fail()    { printf "  ${R}[FAIL]${NC} %s\n" "$1"; FAILS=$((FAILS + 1)); }
info()    { printf "  ${B}[INFO]${NC} %s\n" "$1"; }
note()    { printf "         %s\n" "$1"; }
section() { printf "\n${B}== %s ==${NC}\n" "$1"; }

# Read a KEY=value from the resolved .env without sourcing it.
get_env() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"'; }

# Is a local TCP port being listened on? (POSIX tools; may be absent in Git-Bash)
listening() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -i ":$1" -sTCP:LISTEN -t >/dev/null 2>&1 && return 0
  elif command -v nc >/dev/null 2>&1; then
    nc -z localhost "$1" >/dev/null 2>&1 && return 0
  fi
  return 1
}

printf "${B}Dograh doctor${NC} — read-only diagnostics\n"
printf "         POSIX shell only; for a remote deploy, run this ON the server.\n"

# ---------------------------------------------------------------------------
section "Host & prerequisites"
printf "  ${B}[INFO]${NC} OS: %s (%s)\n" "$(uname -s 2>/dev/null || echo unknown)" "$(uname -m 2>/dev/null || echo '?')"

if command -v docker >/dev/null 2>&1; then
  ok "docker installed: $(docker --version 2>/dev/null | head -1)"
else
  warn "docker is not installed"
  note "Docker is the simplest way to run fresh services, but it's optional. Either install it"
  note "(macOS 'brew install --cask docker'; Linux 'curl -fsSL https://get.docker.com | sh'),"
  note "or reuse existing Postgres/Redis/S3 and run the app natively (references/paths.md)."
  DOCKER_OK=0
fi

if [ "$DOCKER_OK" = 1 ]; then
  if docker info >/dev/null 2>&1; then
    ok "docker daemon is running"
  else
    fail "docker is installed but the daemon is not running"
    note "Start Docker Desktop (macOS/Windows), or 'sudo systemctl start docker' (Linux)."
    DOCKER_OK=0
  fi
fi

if [ "$DOCKER_OK" = 1 ]; then
  if docker compose version >/dev/null 2>&1; then
    ok "docker compose v2: $(docker compose version --short 2>/dev/null || echo present)"
  else
    fail "docker compose v2 plugin not found"
    note "Compose v2 ships with Docker Desktop and recent Docker Engine."
  fi
fi

for t in curl openssl; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t available"; else warn "$t not found (used by the setup scripts)"; fi
done

# ---------------------------------------------------------------------------
section "Deployment"
if [ -z "$DIR" ]; then
  if [ -f "docker-compose.yaml" ] || [ -f "docker-compose.yml" ] || [ -f "docker-compose-local.yaml" ]; then
    DIR="$(pwd)"
  elif [ -f "dograh/docker-compose.yaml" ]; then
    DIR="$(pwd)/dograh"
  else
    DIR="$(pwd)"
  fi
fi
info "deployment directory: $DIR"

COMPOSE_FILE=""
COMPOSE_BASE=""
for f in docker-compose.yaml docker-compose.yml docker-compose-local.yaml; do
  if [ -f "$DIR/$f" ]; then COMPOSE_FILE="$DIR/$f"; COMPOSE_BASE="$f"; break; fi
done

# Dev (contributor) vs deploy. Dev runs the UI on :3000 and the API may be a
# native process (not a container); its infra compose is docker-compose-local.yaml.
if [ "$WANT_MODE" = "dev" ]; then
  DEV=1
elif [ "$WANT_MODE" != "deploy" ] && [ "$COMPOSE_BASE" = "docker-compose-local.yaml" ]; then
  DEV=1
fi
# In dev, the infra is docker-compose-local.yaml even when a deploy compose also exists.
if [ "$DEV" = 1 ] && [ -f "$DIR/docker-compose-local.yaml" ]; then
  COMPOSE_FILE="$DIR/docker-compose-local.yaml"; COMPOSE_BASE="docker-compose-local.yaml"
fi

if [ -n "$COMPOSE_FILE" ]; then
  ok "compose file: $COMPOSE_FILE"
  DEPLOY_FOUND=1
else
  warn "no compose file in $DIR"
  note "Setting up? Expected — pick a path in references/paths.md and run its script."
  note "Debugging? Re-run with --dir <dir> (remote installs live under ./dograh)."
fi

ENV_FILE="$DIR/.env"
if [ "$DEV" = 1 ]; then
  MODE="dev"
  info "detected mode: dev (contributor setup — UI :3000, API :8000)"
  if [ -f "$ENV_FILE" ]; then ok ".env present"; else info "no .env in $DIR (dev uses api/.env and ui/.env)"; fi
elif [ -f "$ENV_FILE" ]; then
  ok ".env present"
  if [ "$(get_env ENVIRONMENT)" = "production" ] || [ -n "$(get_env SERVER_IP)" ]; then
    MODE="remote"; SERVER_IP="$(get_env SERVER_IP)"
  elif [ -n "$(get_env TURN_HOST)" ]; then
    MODE="local-turn"
  else
    MODE="local"
  fi
  info "detected mode: $MODE${SERVER_IP:+ (server $SERVER_IP)}"
elif [ "$DEPLOY_FOUND" = 1 ]; then
  warn "no .env next to the compose file"
  note "Setup scripts generate it (OSS_JWT_SECRET, secrets, TURN creds). Without it the API won't start."
else
  info "no .env yet (expected before setup)"
fi

# ---------------------------------------------------------------------------
section "Services"
if [ "$DOCKER_OK" != 1 ]; then
  warn "skipped — Docker is not available (fix prerequisites first)"
elif [ "$DEPLOY_FOUND" != 1 ]; then
  warn "skipped — no compose file found"
else
  CIDS="$(docker compose -f "$COMPOSE_FILE" ps -aq 2>/dev/null)"
  if [ -z "$CIDS" ]; then
    if [ "$DEV" = 1 ]; then
      warn "no infra containers running for $COMPOSE_BASE"
      note "Dev infra: (cd $DIR && docker compose -f $COMPOSE_BASE up -d). API/UI run separately (uvicorn :8000, npm run dev :3000)."
    else
      fail "the stack is not running (no containers for this project)"
      note "Start it — see references/paths.md for the $MODE start command."
    fi
  else
    docker compose -f "$COMPOSE_FILE" ps 2>/dev/null | sed 's/^/         /'
    printf '\n'
    while read -r cid; do
      [ -z "$cid" ] && continue
      service="$(docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' "$cid" 2>/dev/null)"
      [ -z "$service" ] && service="$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null | sed 's#^/##')"
      status="$(docker inspect --format '{{.State.Status}}' "$cid" 2>/dev/null)"
      health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}-{{end}}' "$cid" 2>/dev/null)"
      exitc="$(docker inspect --format '{{.State.ExitCode}}' "$cid" 2>/dev/null)"
      hs=""; [ "$health" != "-" ] && hs=" ($health)"
      case "$service" in
        dograh-init|dograh_init)
          if [ "$status" = "exited" ] && [ "$exitc" = "0" ]; then
            ok "$service: completed (one-shot init, exit 0 — this is correct)"
          elif [ "$status" = "exited" ]; then
            fail "$service: exited $exitc — config render failed; nginx/coturn won't start"
            note "logs: (cd $DIR && docker compose -f $COMPOSE_BASE logs dograh-init)"
          else
            info "$service: $status"
          fi
          ;;
        *)
          [ "$status" = "running" ] && RUNNING_COUNT=$((RUNNING_COUNT + 1))
          if [ "$status" = "running" ] && { [ "$health" = "healthy" ] || [ "$health" = "-" ]; }; then
            ok "$service: running$hs"
          elif [ "$status" = "running" ] && [ "$health" = "starting" ]; then
            warn "$service: running, health=starting (may still be booting — first boot is 2–3 min)"
          elif [ "$status" = "running" ]; then
            fail "$service: running but UNHEALTHY"
            note "logs: (cd $DIR && docker compose -f $COMPOSE_BASE logs --tail=120 $service)"
          else
            fail "$service: $status$hs exit=$exitc"
            note "logs: (cd $DIR && docker compose -f $COMPOSE_BASE logs --tail=120 $service)"
          fi
          ;;
      esac
    done <<EOF
$CIDS
EOF
  fi
fi

# ---------------------------------------------------------------------------
section "Ports"
if [ "$MODE" = "remote" ]; then
  info "remote mode — UI is on 80/443 via nginx; TURN uses 3478/5349 + UDP 49152-49200."
  note "These are validated by the URL probe below and must be open in the server firewall."
elif command -v lsof >/dev/null 2>&1 || command -v nc >/dev/null 2>&1; then
  UI_PORT=3010; [ "$MODE" = "dev" ] && UI_PORT=3000
  for p in "$UI_PORT" 8000 5432 6379 9000 9001; do
    if listening "$p"; then info "port $p: in use"; else info "port $p: free"; fi
  done
  note "Stack up → these should be in use. Already in use before setup → a conflict (debug.md → port in use)."
else
  info "port check skipped — no lsof/nc on this shell (common in Git-Bash)."
  note "Use 'docker compose ps' for published ports, or PowerShell 'Get-NetTCPConnection -LocalPort <p>'."
fi

# ---------------------------------------------------------------------------
section "API health endpoint"
if ! command -v curl >/dev/null 2>&1; then
  warn "curl missing — cannot probe the API"
else
  if [ "$MODE" = "remote" ] && [ -n "$SERVER_IP" ]; then
    HURL="https://$SERVER_IP/api/v1/health"; COPTS="-k"
  else
    HURL="http://localhost:8000/api/v1/health"; COPTS=""
  fi
  BODY="$(curl $COPTS -fsS --max-time 8 "$HURL" 2>/dev/null)"
  if [ -n "$BODY" ]; then
    if [ "$DOCKER_OK" = 1 ] && [ "$MODE" != "dev" ] && [ "$DEPLOY_FOUND" = 1 ] && [ "$RUNNING_COUNT" -eq 0 ]; then
      warn "endpoint answered at $HURL, but this project has 0 running containers"
      note "Almost certainly a DIFFERENT service on the port, not this Dograh stack."
      note "Trust 'docker compose ps' over a bare port. (Dev API runs natively — pass --mode dev.)"
    else
      ok "health endpoint reachable: $HURL"
    fi
    if command -v jq >/dev/null 2>&1; then
      printf '%s' "$BODY" | jq -r '"         status=\(.status)  version=\(.version)  mode=\(.deployment_mode)  turn=\(.turn_enabled)"' 2>/dev/null || note "$BODY"
    else
      note "$BODY"
    fi
  else
    fail "health endpoint NOT reachable: $HURL"
    note "Inspect the API: (cd $DIR && docker compose logs --tail=150 api), or the uvicorn logs in dev."
    note "See references/debug.md → 'API health check failing'."
  fi
fi

# ---------------------------------------------------------------------------
section "Web UI"
if ! command -v curl >/dev/null 2>&1; then
  warn "curl missing — cannot probe the UI"
else
  if [ "$MODE" = "remote" ] && [ -n "$SERVER_IP" ]; then
    UURL="https://$SERVER_IP"; UOPTS="-k"
  elif [ "$MODE" = "dev" ]; then
    UURL="http://localhost:3000"; UOPTS=""
  else
    UURL="http://localhost:3010"; UOPTS=""
  fi
  CODE="$(curl $UOPTS -s -o /dev/null -w '%{http_code}' --max-time 8 "$UURL" 2>/dev/null)"
  [ -z "$CODE" ] && CODE="000"
  case "$CODE" in
    200|301|302|307|308) ok "UI reachable at $UURL (HTTP $CODE)" ;;
    *)
      fail "UI not reachable at $UURL (HTTP $CODE)"
      if [ "$MODE" = "remote" ]; then
        note "Remote UI is served by nginx on 443, not :3010. Check nginx + firewall (debug.md → remote-only)."
      else
        note "Check the ui (container in deploy, or 'npm run dev' in dev). It also needs the API healthy (debug.md → UI not loading)."
      fi
      ;;
  esac
fi

# ---------------------------------------------------------------------------
section ".env sanity"
if [ "$MODE" = "dev" ]; then
  info "dev mode — config lives in api/.env and ui/.env (not a single deploy .env)."
  note "If the API won't boot, check DATABASE_URL / REDIS_URL / OSS_JWT_SECRET in api/.env (developer/environment-variables)."
elif [ ! -f "$ENV_FILE" ]; then
  if [ "$DEPLOY_FOUND" = 1 ]; then
    fail "no .env — OSS_JWT_SECRET will be missing and the API will refuse to start"
  else
    info "no .env yet (expected before setup)"
  fi
else
  check_key() {
    if [ -n "$(get_env "$1")" ]; then ok ".env has $1"; else fail ".env is missing $1"; fi
  }
  check_key OSS_JWT_SECRET
  if [ "$MODE" = "remote" ]; then
    check_key SERVER_IP
    check_key POSTGRES_PASSWORD
    check_key TURN_HOST
    check_key TURN_SECRET
  elif [ "$MODE" = "local-turn" ]; then
    check_key TURN_HOST
    check_key TURN_SECRET
  fi
fi

# ---------------------------------------------------------------------------
section "Resources"
AVAIL_KB="$(df -Pk "$DIR" 2>/dev/null | awk 'NR==2 {print $4}')"
if [ -n "${AVAIL_KB:-}" ] && [ "$AVAIL_KB" -eq "$AVAIL_KB" ] 2>/dev/null; then
  AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
  if [ "$AVAIL_GB" -lt 5 ]; then
    fail "low disk: ~${AVAIL_GB}GB free at $DIR (Dograh needs ~10GB)"
  else
    ok "disk: ~${AVAIL_GB}GB free at $DIR"
  fi
fi
if [ "$DOCKER_OK" = 1 ]; then
  info "docker disk usage:"
  docker system df 2>/dev/null | sed 's/^/         /'
fi

# ---------------------------------------------------------------------------
section "Summary"
if [ "$FAILS" -gt 0 ]; then
  printf "  ${R}%s failure(s)${NC}, ${Y}%s warning(s)${NC}.\n" "$FAILS" "$WARNS"
  note "Start with the first [FAIL] above and follow references/debug.md."
  exit 2
elif [ "$WARNS" -gt 0 ]; then
  printf "  ${Y}%s warning(s)${NC}, no failures.\n" "$WARNS"
  note "Likely healthy or mid-setup — review the [WARN] lines."
  exit 1
else
  printf "  ${G}All checks passed — Dograh looks healthy.${NC}\n"
  exit 0
fi
