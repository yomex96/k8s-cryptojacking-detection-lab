#!/usr/bin/env bash
# Builds the lab: kind cluster (Calico for NetworkPolicy), Prometheus, Falco, workloads.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Creating kind cluster (default CNI disabled so Calico can enforce NetworkPolicy)"
cat > /tmp/kind-calico.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cryptojack-lab
networking:
  disableDefaultCNI: true
nodes:
  - role: control-plane
  - role: worker
EOF
kind create cluster --config /tmp/kind-calico.yaml

echo "==> Installing Calico"
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
kubectl -n kube-system rollout status ds/calico-node --timeout=300s

echo "==> Building and loading simulator image"
docker build -t miner-sim:lab simulator/
kind load docker-image miner-sim:lab --name cryptojack-lab

echo "==> Installing kube-prometheus-stack"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace --wait

echo "==> Installing Falco with custom cryptojacking rules"
helm upgrade --install falco falcosecurity/falco -n falco --create-namespace \
  --set driver.kind=modern_ebpf --set tty=true \
  -f detection/falco-rules.yaml --wait

echo "==> Applying Prometheus alert rule"
kubectl apply -f detection/prometheus-alert.yaml

echo "==> Deploying workloads (fake pool + disguised miner simulator)"
kubectl apply -f k8s/workloads.yaml
kubectl -n cryptojack-lab rollout status deploy/fake-pool --timeout=120s
kubectl -n cryptojack-lab rollout status deploy/report-worker --timeout=120s
echo "==> Lab ready. Run scripts/detect.sh to see detections."
