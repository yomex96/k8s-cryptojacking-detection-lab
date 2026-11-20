# Kubernetes Cryptojacking Detection Lab

A local lab that reproduces a cryptojacking incident in Kubernetes, detects it in two independent ways, and walks through incident response: evidence preservation, quarantine, eradication and prevention.

The lab is based on a real-world pattern: an unauthorised mining process hidden inside an innocent-looking workload, noticed first as unusual CPU usage.

> **Safety:** no cryptocurrency is mined. `simulator/miner_sim.py` only imitates a miner's *behaviour* (CPU burn plus Stratum-style beacons) against a harmless fake pool running inside the same local cluster. Run this only on your own machine.

## Threat model

| | |
|---|---|
| **Attacker goal** | Use the victim's compute to mine cryptocurrency (MITRE ATT&CK T1496, Resource Hijacking) |
| **Foothold (assumed)** | A compromised image or deployment running in the cluster |
| **Disguise** | The workload is named `report-worker`, so it looks like a normal batch job |
| **Observable signals** | Sustained high CPU; outbound connections to mining-pool ports (3333, 4444, 5555...); Stratum `login` messages |

## Architecture

```
kind cluster (Calico CNI)
├── namespace cryptojack-lab
│   ├── report-worker   <- disguised miner simulator (CPU burn + beacons)
│   └── fake-pool:3333  <- harmless echo service acting as a mining pool
├── namespace monitoring -> kube-prometheus-stack + SustainedHighContainerCPU alert
└── namespace falco      -> Falco (modern eBPF) + custom cryptojacking rules
```

## Detection layers

1. **Metrics (Prometheus):** `SustainedHighContainerCPU` fires when a container uses more than 0.8 cores for 2 minutes (`detection/prometheus-alert.yaml`).
2. **Runtime behaviour (Falco):** custom rules in `detection/falco-rules.yaml`:
   - *Outbound Connection to Common Mining Pool Port*: a container connects to a known Stratum port.
   - *Stratum Protocol Login Pattern*: a container sends a Stratum-like `login` message.

Two layers matter: CPU alone is noisy (legitimate jobs spike too), while network behaviour shows **intent**.

## Requirements

Docker, [kind](https://kind.sigs.k8s.io/), kubectl, Helm 3, and a Linux kernel 5.8+ for Falco's modern eBPF driver (on macOS/Windows, Docker Desktop's VM kernel works).

## Run it

```bash
./scripts/setup.sh      # cluster, Calico, Prometheus, Falco, workloads (~10 min)
./scripts/detect.sh     # wait ~3 minutes first, then view CPU, Falco alerts and beacons
./scripts/respond.sh    # preserve evidence -> quarantine -> eradicate -> prevent
./scripts/teardown.sh   # delete everything
```

To see the Prometheus alert:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090
# open http://localhost:9090/alerts
```

## Incident response steps (`scripts/respond.sh`)

1. **Preserve evidence first:** pod spec, logs, process list and Falco alerts are saved to `evidence/` before anything changes.
2. **Contain:** `response/quarantine-networkpolicy.yaml` blocks all traffic to and from the pod. Beacons start failing, but the pod stays available for investigation.
3. **Eradicate:** the compromised deployment is scaled to zero.
4. **Prevent recurrence:** `response/prevention-default-deny-egress.yaml` applies default-deny egress (DNS only) to the namespace.

## Results

<!-- Add your own screenshots after running the lab -->
- `docs/falco-alert.png`: Falco alert output
- `docs/prometheus-alert.png`: the firing CPU alert
- `docs/quarantine.png`: beacons failing after quarantine

## Limitations and next steps

- Port-based detection is easy to evade (miners can use 443 or TLS). Next step: detect by destination reputation or DNS (known pool domains).
- The Stratum payload rule fails against encrypted pool connections.
- Admission control (signed images, Kyverno/OPA policies) would stop the workload from being deployed in the first place.

## Author

Abayomi Robert Onawole
