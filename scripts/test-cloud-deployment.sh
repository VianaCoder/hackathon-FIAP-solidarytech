#!/usr/bin/env bash
# Smoke-tests the SolidaryTech dev environment running on AWS/EKS.
#
# Validates, in order:
#   1. kubectl connectivity to the expected cluster
#   2. Node readiness
#   3. Argo CD Application sync/health status
#   4. Pod readiness for ngo-service, donation-service, volunteer-service
#   5. Functional smoke test of each service's HTTP API via kubectl port-forward
#   6. Presence of pushed images in the 3 ECR repositories
#
# Requirements: kubectl (configured for the target cluster), aws CLI, curl, jq.
#
# Usage:
#   ./scripts/test-cloud-deployment.sh
#
# Optional env vars:
#   EKS_CLUSTER_NAME=solidarytech-dev-eks
#   AWS_REGION=us-east-1
#   AWS_PROFILE=terraform-admin

set -uo pipefail

EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-solidarytech-dev-eks}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_PROFILE="${AWS_PROFILE:-terraform-admin}"
export AWS_PROFILE AWS_REGION

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
section() { echo; echo "== $1 =="; }

PF_PIDS=()
cleanup() {
  for pid in "${PF_PIDS[@]:-}"; do
    kill "$pid" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

section "1. kubectl context"
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
if [[ "$CURRENT_CONTEXT" == *"$EKS_CLUSTER_NAME"* ]]; then
  pass "kubectl context points to $EKS_CLUSTER_NAME"
else
  fail "kubectl context is '$CURRENT_CONTEXT', expected to reference $EKS_CLUSTER_NAME"
fi

section "2. Node readiness"
NODE_LINES=$(kubectl get nodes --no-headers 2>/dev/null || echo "")
NODE_COUNT=$(echo "$NODE_LINES" | grep -c . || true)
READY_COUNT=$(echo "$NODE_LINES" | awk '$2=="Ready"' | wc -l)
if [[ "$NODE_COUNT" -gt 0 && "$NODE_COUNT" == "$READY_COUNT" ]]; then
  pass "$READY_COUNT/$NODE_COUNT nodes Ready"
else
  fail "$READY_COUNT/$NODE_COUNT nodes Ready"
fi

section "3. Argo CD Application status"
APP_LINES=$(kubectl get applications -n argocd --no-headers 2>/dev/null || echo "")
if [[ -z "$APP_LINES" ]]; then
  fail "no Argo CD Applications found in namespace argocd"
else
  while read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    sync=$(echo "$line" | awk '{print $2}')
    health=$(echo "$line" | awk '{print $3}')
    if [[ "$sync" == "Synced" && ( "$health" == "Healthy" || "$health" == "Progressing" ) ]]; then
      pass "Application $name: sync=$sync health=$health"
    else
      fail "Application $name: sync=$sync health=$health"
    fi
  done <<< "$APP_LINES"
fi

section "4. Pod readiness per service"
declare -A NAMESPACES=(
  [ngo-service]=ns-ngo
  [donation-service]=ns-donation
  [volunteer-service]=ns-volunteer
)
for svc in "${!NAMESPACES[@]}"; do
  ns="${NAMESPACES[$svc]}"
  pod_lines=$(kubectl get pods -n "$ns" -l "app=$svc" --no-headers 2>/dev/null || echo "")
  total=$(echo "$pod_lines" | grep -c . || true)
  ready=$(echo "$pod_lines" | awk -F'[ /]+' '$2==$3 && $3!="" {c++} END{print c+0}')
  if [[ "$total" -gt 0 && "$ready" == "$total" ]]; then
    pass "$svc: $ready/$total pods Ready in $ns"
  else
    fail "$svc: $ready/$total pods Ready in $ns"
  fi
done

section "5. Functional API smoke tests (via kubectl port-forward)"

port_forward() {
  local svc="$1" ns="$2" local_port="$3" remote_port="$4"
  kubectl port-forward -n "$ns" "svc/$svc" "$local_port:$remote_port" >/tmp/pf-"$svc".log 2>&1 &
  local pid=$!
  PF_PIDS+=("$pid")
  for _ in $(seq 1 10); do
    if curl -s -o /dev/null "http://127.0.0.1:$local_port/health"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# ngo-service: health + create/list an NGO
if port_forward ngo-service ns-ngo 18081 8081; then
  health=$(curl -s http://127.0.0.1:18081/health)
  if echo "$health" | grep -q '"status":"ok"'; then
    pass "ngo-service /health: $health"
  else
    fail "ngo-service /health returned unexpected body: $health"
  fi

  create_resp=$(curl -s -X POST http://127.0.0.1:18081/ngos \
    -H 'Content-Type: application/json' \
    -d '{"name":"Smoke Test NGO","email":"smoke-test+'"$RANDOM"'@example.com","cause":"test","city":"test"}')
  if echo "$create_resp" | jq -e '.id' >/dev/null 2>&1; then
    pass "ngo-service POST /ngos created record id=$(echo "$create_resp" | jq -r .id)"
  else
    fail "ngo-service POST /ngos failed: $create_resp"
  fi

  list_resp=$(curl -s http://127.0.0.1:18081/ngos)
  if echo "$list_resp" | jq -e 'type=="array"' >/dev/null 2>&1; then
    pass "ngo-service GET /ngos returned $(echo "$list_resp" | jq 'length') record(s)"
  else
    fail "ngo-service GET /ngos failed: $list_resp"
  fi
else
  fail "ngo-service port-forward did not become ready"
fi

# donation-service: health + create/list a donation
if port_forward donation-service ns-donation 18082 8082; then
  health=$(curl -s http://127.0.0.1:18082/health)
  if echo "$health" | grep -q '"status":"ok"'; then
    pass "donation-service /health: $health"
  else
    fail "donation-service /health returned unexpected body: $health"
  fi

  create_resp=$(curl -s -X POST http://127.0.0.1:18082/donations \
    -H 'Content-Type: application/json' \
    -d '{"ngo_id":1,"amount":10.50,"donor_name":"Smoke Test"}')
  if echo "$create_resp" | jq -e '.id' >/dev/null 2>&1; then
    pass "donation-service POST /donations created record id=$(echo "$create_resp" | jq -r .id)"
  else
    fail "donation-service POST /donations failed: $create_resp"
  fi

  list_resp=$(curl -s http://127.0.0.1:18082/donations)
  if echo "$list_resp" | jq -e 'type=="array"' >/dev/null 2>&1; then
    pass "donation-service GET /donations returned $(echo "$list_resp" | jq 'length') record(s)"
  else
    fail "donation-service GET /donations failed: $list_resp"
  fi
else
  fail "donation-service port-forward did not become ready"
fi

# volunteer-service: health + register/list a volunteer
if port_forward volunteer-service ns-volunteer 18083 8083; then
  health=$(curl -s http://127.0.0.1:18083/health)
  if echo "$health" | grep -q '"status":"ok"'; then
    pass "volunteer-service /health: $health"
  else
    fail "volunteer-service /health returned unexpected body: $health"
  fi

  create_resp=$(curl -s -X POST http://127.0.0.1:18083/volunteers \
    -H 'Content-Type: application/json' \
    -d '{"name":"Smoke Test Volunteer","email":"smoke-test+'"$RANDOM"'@example.com","ngo_id":1}')
  if echo "$create_resp" | jq -e '.volunteer_id' >/dev/null 2>&1; then
    ngo_id=$(echo "$create_resp" | jq -r .ngo_id)
    pass "volunteer-service POST /volunteers created record volunteer_id=$(echo "$create_resp" | jq -r .volunteer_id)"

    list_resp=$(curl -s "http://127.0.0.1:18083/volunteers/$ngo_id")
    if echo "$list_resp" | jq -e 'type=="array"' >/dev/null 2>&1; then
      pass "volunteer-service GET /volunteers/$ngo_id returned $(echo "$list_resp" | jq 'length') record(s)"
    else
      fail "volunteer-service GET /volunteers/$ngo_id failed: $list_resp"
    fi
  else
    fail "volunteer-service POST /volunteers failed: $create_resp"
  fi
else
  fail "volunteer-service port-forward did not become ready"
fi

section "6. ECR image presence"
for repo in ngo-service donation-service volunteer-service; do
  tags=$(aws ecr describe-images --repository-name "$repo" --region "$AWS_REGION" \
    --query 'imageDetails[].imageTags[]' --output text 2>/dev/null)
  if [[ -n "$tags" ]]; then
    pass "ECR $repo has image(s): $tags"
  else
    fail "ECR $repo has no images"
  fi
done

section "Summary"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
