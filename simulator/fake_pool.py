"""Harmless fake 'mining pool' for the lab: accepts TCP connections and replies OK."""
import socketserver


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        line = self.rfile.readline(512)
        print(f"[pool] connection from {self.client_address[0]}: {line[:80]!r}", flush=True)
        self.wfile.write(b'{"id":1,"result":"LAB-OK","error":null}\n')


if __name__ == "__main__":
    with socketserver.ThreadingTCPServer(("0.0.0.0", 3333), Handler) as srv:
        print("[pool] listening on :3333", flush=True)
        srv.serve_forever()
