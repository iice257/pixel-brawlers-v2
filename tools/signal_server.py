"""Tiny signalling relay for REDLINE online play (WebRTC offer, answer and ICE candidates), standard library only.
Rooms live in memory for 15 minutes and carry nothing but connection setup messages; the match itself goes peer to peer.
Run:  python tools/signal_server.py [port]        (default 8787; put it behind any free HTTPS host for phones)
  GET  /new                      -> {"code": "K7QX"}              reserve an unused room code
  POST /r/<code>/<to>            body = one message (text)       queue it for "host" or "guest"
  GET  /r/<code>/<role>?since=N  -> {"msgs": [...], "next": M}   messages addressed to role from index N on
"""
import json
import random
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
TTL = 15 * 60
rooms = {}   # code -> {"t": last_used, "host": [msgs for host], "guest": [msgs for guest]}


def sweep():
    now = time.time()
    for c in [c for c, r in rooms.items() if now - r["t"] > TTL]:
        del rooms[c]


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json"):
        data = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self):
        self._send(204, "")

    def do_GET(self):
        sweep()
        u = urlparse(self.path)
        parts = [p for p in u.path.split("/") if p]
        if parts == ["new"]:
            for _ in range(200):
                code = "".join(random.choice(ALPHABET) for _ in range(4))
                if code not in rooms:
                    rooms[code] = {"t": time.time(), "host": [], "guest": []}
                    return self._send(200, json.dumps({"code": code}))
            return self._send(503, "{}")
        if len(parts) == 3 and parts[0] == "r" and parts[2] in ("host", "guest"):
            room = rooms.get(parts[1].upper())
            if room is None:
                return self._send(404, json.dumps({"error": "no such room"}))
            room["t"] = time.time()
            since = int(parse_qs(u.query).get("since", ["0"])[0])
            box = room[parts[2]]
            return self._send(200, json.dumps({"msgs": box[since:], "next": len(box)}))
        if not parts:
            return self._send(200, "REDLINE signalling relay", "text/plain")
        self._send(404, "{}")

    def do_POST(self):
        parts = [p for p in urlparse(self.path).path.split("/") if p]
        if len(parts) == 3 and parts[0] == "r" and parts[2] in ("host", "guest"):
            n = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(min(n, 16384)).decode("utf-8", "replace")
            room = rooms.setdefault(parts[1].upper(), {"t": time.time(), "host": [], "guest": []})
            room["t"] = time.time()
            room[parts[2]].append(body)
            return self._send(200, "{}")
        self._send(404, "{}")

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
    print("signalling relay on port", port, flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
