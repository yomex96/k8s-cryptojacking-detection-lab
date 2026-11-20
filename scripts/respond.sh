#!/usr/bin/env bash
# Incident response: preserve evidence, quarantine, then remove and prevent recurrence.
set -euo pipefail
cd "$(dirname "$0")/.."
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p evidence

echo "==> 1. Preserve evidence before changing anything"
POD=$(kubectl -n cryptojack-lab get pod -l app=report-worker -o jsonpath='{.items[0].metadata.name}')
kubectl -n cryptojack-lab get pod "$POD" -o yaml > "evidence/${TS}-pod.yaml"
kubectl -n cryptojack-lab logs "$POD" > "evidence/${TS}-pod.log"
kubectl -n cryptojack-lab exec "$POD" -- ps aux > "evidence/${TS}-processes.txt" 2>/dev/null || true
kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --tail=2000 \
  | grep -Ei "cryptojacking|Stratum" > "evidence/${TS}-falco-alerts.log" || true
echo "    saved to evidence/"

echo "==> 2. Quarantine the pod (deny all ingress and egress)"
kubectl apply -f response/quarantine-networkpolicy.yaml
sleep 20
echo "    beacons after quarantine (should now fail):"
kubectl -n cryptojack-lab logs "$POD" --tail=3

echo "==> 3. Eradicate: scale the compromised deployment to zero"
kubectl -n cryptojack-lab scale deploy/report-worker --replicas=0

echo "==> 4. Prevent: default-deny egress for the namespace"
kubectl apply -f response/prevention-default-deny-egress.yaml
echo "==> Done. Evidence in evidence/, quarantine and prevention policies applied."
