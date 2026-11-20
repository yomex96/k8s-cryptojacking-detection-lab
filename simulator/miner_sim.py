"""
Cryptojacking SIMULATOR - safe for lab use.

It does NOT mine cryptocurrency. It only reproduces the two behaviours that
detection tools look for in a real cryptojacking workload:

  1. Sustained high CPU usage (busy loops that hash random data).
  2. Repeated outbound TCP connections to a "mining pool" port (3333 by default),
     sending a fake Stratum-style login line, like real miners do.

The "pool" is a harmless echo service running inside the same lab cluster.
"""
import hashlib
import json
import multiprocessing
import os
import socket
import time

POOL_HOST = os.getenv("POOL_HOST", "fake-pool.cryptojack-lab.svc.cluster.local")
POOL_PORT = int(os.getenv("POOL_PORT", "3333"))
WORKERS = int(os.getenv("WORKERS", "2"))
CONNECT_EVERY_SECONDS = int(os.getenv("CONNECT_EVERY_SECONDS", "15"))


def burn_cpu(worker_id: int) -> None:
    data = os.urandom(64)
    while True:
        for _ in range(200_000):
            data = hashlib.sha256(data).digest()


def beacon_to_pool() -> None:
    login = json.dumps({"id": 1, "method": "login",
                        "params": {"login": "LAB-SIMULATION-ONLY", "pass": "x"}}) + "\n"
    while True:
        try:
            with socket.create_connection((POOL_HOST, POOL_PORT), timeout=5) as s:
                s.sendall(login.encode())
                s.recv(256)
                print(f"[sim] beacon sent to {POOL_HOST}:{POOL_PORT}", flush=True)
        except OSError as exc:
            print(f"[sim] beacon failed: {exc}", flush=True)
        time.sleep(CONNECT_EVERY_SECONDS)


if __name__ == "__main__":
    print(f"[sim] starting {WORKERS} CPU workers; pool={POOL_HOST}:{POOL_PORT}", flush=True)
    for i in range(WORKERS):
        multiprocessing.Process(target=burn_cpu, args=(i,), daemon=True).start()
    beacon_to_pool()
