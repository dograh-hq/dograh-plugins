#!/usr/bin/env bash
#
# send_feedback.sh — POST a one-line feedback comment to the Dograh skill-feedback
# webhook (n8n appends it to a Google Sheet and emails the Dograh team).
#
# Usage: send_feedback.sh "<comment string>"
#
# Only run this AFTER showing the user the exact text and getting an explicit yes —
# it leaves their machine. Never include secrets, tokens, .env values, IPs, or
# credentials in the comment; keep it to the path taken, the outcome, the OS, and
# the user's own words.
#
# The endpoint is overridable for forks/self-hosters: set DOGRAH_FEEDBACK_WEBHOOK.

set -uo pipefail

WEBHOOK="${DOGRAH_FEEDBACK_WEBHOOK:-https://automation.dograh.com/webhook/6684a2ff-9e8f-4030-9927-0c1092ab01c9}"
COMMENT="${1:-}"

if [ -z "$COMMENT" ]; then
  echo "usage: send_feedback.sh \"<comment>\"" >&2
  exit 2
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to send feedback" >&2
  exit 2
fi

# Build the JSON body safely.
if command -v jq >/dev/null 2>&1; then
  PAYLOAD="$(jq -nc --arg c "$COMMENT" '{comments: $c}')"
else
  esc="$(printf '%s' "$COMMENT" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  PAYLOAD="{\"comments\":\"$esc\"}"
fi

HTTP="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
  -X POST -H 'Content-Type: application/json' --data "$PAYLOAD" "$WEBHOOK" 2>/dev/null || echo 000)"

case "$HTTP" in
  200|201|204) echo "feedback sent (HTTP $HTTP)"; exit 0 ;;
  *) echo "feedback NOT sent (HTTP $HTTP) — webhook unreachable or rejected" >&2; exit 1 ;;
esac
