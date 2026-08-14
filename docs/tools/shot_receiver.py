#!/usr/bin/env python3
"""Tiny local HTTP receiver: accepts POST /save?name=X.png with a raw PNG
body and writes it to the screenshots/ dir next to this script. Exists so
browser-captured canvas screenshots can be persisted to disk without
routing the (large) base64 payload through the agent's own context.
"""
import http.server
import os
import urllib.parse

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "screenshots")
os.makedirs(OUT_DIR, exist_ok=True)


class Handler(http.server.BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/save":
            self.send_response(404)
            self._cors()
            self.end_headers()
            return
        qs = urllib.parse.parse_qs(parsed.query)
        name = qs.get("name", ["shot.png"])[0]
        name = os.path.basename(name)  # no path traversal
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        out_path = os.path.join(OUT_DIR, name)
        with open(out_path, "wb") as f:
            f.write(body)
        self.send_response(200)
        self._cors()
        self.end_headers()
        self.wfile.write(f"saved {name} ({length} bytes)".encode())
        print(f"saved {name} ({length} bytes)")

    def log_message(self, fmt, *args):
        pass  # keep stdout clean, we print manually above


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", 5050), Handler)
    print("shot_receiver listening on :5050, writing to", OUT_DIR)
    server.serve_forever()
