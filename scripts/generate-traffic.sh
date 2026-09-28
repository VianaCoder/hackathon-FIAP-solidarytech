#!/usr/bin/env bash
# Generates sustained end-to-end traffic against ngo-service, donation-service
# and volunteer-service via the public HTTPS API ingress
# (api.gvianalourenco.xyz), so traces/metrics flow through the full path:
#   client -> nginx ingress -> service -> OTel SDK -> otel-collector -> New Relic
#
# Unlike scripts/test-cloud-deployment.sh (one-shot smoke test via
# port-forward), this script drives sustained, parallel, repeated load
# directly against the public endpoints for a configurable duration.
#
# Usage:
#   ./scripts/generate-traffic.sh [duration_seconds] [concurrency]
#
# Examples:
#   ./scripts/generate-traffic.sh            # 120s, concurrency 5 (defaults)
#   ./scripts/generate-traffic.sh 300 10     # 300s, concurrency 10
#
# Optional env vars:
#   API_BASE_URL=https://api.gvianalourenco.xyz   # override base URL
#   REQUEST_DELAY=0.2                             # seconds between requests per worker

set -uo pipefail

DURATION="${1:-120}"
CONCURRENCY="${2:-5}"
API_BASE_URL="${API_BASE_URL:-https://api.gvianalourenco.xyz}"
REQUEST_DELAY="${REQUEST_DELAY:-0.2}"

echo "Target:      $API_BASE_URL"
echo "Duration:    ${DURATION}s"
echo "Concurrency: $CONCURRENCY workers per route"
echo

STOP_AT=$(( $(date +%s) + DURATION ))

REQ_COUNT_FILE=$(mktemp)
ERR_COUNT_FILE=$(mktemp)
echo 0 > "$REQ_COUNT_FILE"
echo 0 > "$ERR_COUNT_FILE"

record_result() {
  local status="$1"
  # flock avoids lost updates when many workers increment concurrently
  {
    flock -x 200
    local n
    n=$(cat "$REQ_COUNT_FILE")
    echo $((n + 1)) > "$REQ_COUNT_FILE"
    if [[ "$status" -lt 200 || "$status" -ge 400 ]]; then
      local e
      e=$(cat "$ERR_COUNT_FILE")
      echo $((e + 1)) > "$ERR_COUNT_FILE"
    fi
  } 200>"$REQ_COUNT_FILE.lock"
}

# --- Worker: ngo-service traffic (create + list) ---
ngo_worker() {
  while [[ $(date +%s) -lt $STOP_AT ]]; do
    local rid=$RANDOM
    local status
    status=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API_BASE_URL/ngo/ngos" \
      -H 'Content-Type: application/json' \
      -d "{\"name\":\"Load Test NGO $rid\",\"email\":\"load-test-$rid@example.com\",\"cause\":\"test\",\"city\":\"test\"}")
    record_result "$status"

    status=$(curl -s -o /dev/null -w '%{http_code}' "$API_BASE_URL/ngo/ngos")
    record_result "$status"

    sleep "$REQUEST_DELAY"
  done
}

# --- Worker: donation-service traffic (create + list) ---
# Note: the Ingress rewrite regex requires the path segment to be repeated
# (e.g. /donations/donations), since the Ingress prefix equals the
# backend's own route name. Confirmed empirically via curl.
donation_worker() {
  while [[ $(date +%s) -lt $STOP_AT ]]; do
    local amount
    amount=$(awk -v seed="$RANDOM" 'BEGIN{srand(seed); printf "%.2f", 5 + rand()*95}')
    local status
    status=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API_BASE_URL/donations/donations" \
      -H 'Content-Type: application/json' \
      -d "{\"ngo_id\":1,\"amount\":$amount,\"donor_name\":\"Load Test Donor\"}")
    record_result "$status"

    status=$(curl -s -o /dev/null -w '%{http_code}' "$API_BASE_URL/donations/donations")
    record_result "$status"

    sleep "$REQUEST_DELAY"
  done
}

# --- Worker: volunteer-service traffic (create + list) ---
# Same Ingress rewrite quirk as donation-service: path segment repeated.
volunteer_worker() {
  while [[ $(date +%s) -lt $STOP_AT ]]; do
    local rid=$RANDOM
    local status
    status=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API_BASE_URL/volunteers/volunteers" \
      -H 'Content-Type: application/json' \
      -d "{\"name\":\"Load Test Volunteer $rid\",\"email\":\"load-test-$rid@example.com\",\"ngo_id\":1}")
    record_result "$status"

    status=$(curl -s -o /dev/null -w '%{http_code}' "$API_BASE_URL/volunteers/volunteers/1")
    record_result "$status"

    sleep "$REQUEST_DELAY"
  done
}

PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT INT TERM

for _ in $(seq 1 "$CONCURRENCY"); do
  ngo_worker &
  PIDS+=($!)
  donation_worker &
  PIDS+=($!)
  volunteer_worker &
  PIDS+=($!)
done

echo "Started $((CONCURRENCY * 3)) workers (${CONCURRENCY} per service). Running for ${DURATION}s..."

# Progress reporting every 10s
while [[ $(date +%s) -lt $STOP_AT ]]; do
  sleep 10
  total=$(cat "$REQ_COUNT_FILE")
  errors=$(cat "$ERR_COUNT_FILE")
  remaining=$((STOP_AT - $(date +%s)))
  echo "  [progress] requests=$total errors=$errors remaining=${remaining}s"
done

wait

TOTAL=$(cat "$REQ_COUNT_FILE")
ERRORS=$(cat "$ERR_COUNT_FILE")
rm -f "$REQ_COUNT_FILE" "$REQ_COUNT_FILE.lock" "$ERR_COUNT_FILE"

echo
echo "== Summary =="
echo "  Total requests: $TOTAL"
echo "  Errors (non-2xx/3xx): $ERRORS"
echo
echo "Traces/metrics should now be visible in New Relic APM for:"
echo "  ngo-service, donation-service, volunteer-service"
