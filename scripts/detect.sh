#!/usr/bin/env bash
# Shows the evidence: CPU usage, Falco alerts, and the miner's beacons.
set -uo pipefail

echo "==> 1. CPU usage per pod (needs metrics; kube-prometheus-stack can take a minute)"
kubectl top pods -n cryptojack-lab 2>/dev/null || echo "(kubectl top unavailable; check Grafana instead)"

echo
echo "==> 2. Falco alerts mentioning cryptojacking (last 50 lines)"
kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --tail=500 \
  | grep -Ei "cryptojacking|Stratum" | tail -n 50

echo
echo "==> 3. Simulator beacons"
kubectl logs -n cryptojack-lab deploy/report-worker --tail=5

echo
echo "==> 4. Prometheus alert status: open http://localhost:9090/alerts after running:"
echo "    kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090"
