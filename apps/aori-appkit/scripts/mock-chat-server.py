#!/usr/bin/env python3
"""OpenAI-compatible mock. One bearer token returns one streamed reply."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORT = 8765
TOKEN = "Bearer ci-mock-key"
REPLY = (
    'data: {"choices":[{"delta":{"content":"Mock reply from CI."}}]}\n\n'
    "data: [DONE]\n\n"
)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length > 0:
            self.rfile.read(length)
        if self.headers.get("Authorization", "") != TOKEN:
            body = b'{"error":"unauthorized"}'
            self._send(401, "application/json", body)
            return
        if not self.path.split("?", 1)[0].rstrip("/").endswith("/chat/completions"):
            body = b'{"error":"not found"}'
            self._send(404, "application/json", body)
            return
        self._send(200, "text/event-stream", REPLY.encode())

    def _send(self, status, content_type, body):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
