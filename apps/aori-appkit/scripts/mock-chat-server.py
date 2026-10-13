#!/usr/bin/env python3
"""OpenAI-compatible mock. Chat text, vision images, and embeddings use one token."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORT = 8765
TOKEN = "Bearer ci-mock-key"


def local_embedding(text):
    dims = 32
    buckets = [0.0] * dims
    for raw in text.lower().split():
        cleaned = "".join(ch for ch in raw if "a" <= ch <= "z")
        if not cleaned:
            continue
        hash_value = 2166136261
        for ch in cleaned:
            hash_value ^= ord(ch)
            hash_value = (hash_value * 16777619) & 0xFFFFFFFF
        buckets[hash_value % dims] += 1.0
    norm = sum(value * value for value in buckets) ** 0.5
    if norm == 0.0:
        return buckets
    return [value / norm for value in buckets]


def embedding_body(payload):
    text = ""
    try:
        body = json.loads(payload.decode("utf-8"))
        raw = body.get("input", "")
        if isinstance(raw, str):
            text = raw
    except json.JSONDecodeError:
        text = ""
    encoded = json.dumps({"data": [{"embedding": local_embedding(text)}]}).encode()
    return encoded


def reply_for(payload):
    text = payload.decode("utf-8", "replace").replace("\\/", "/")
    if "image_url" in text and "data:image/png;base64," in text:
        content = "Mock vision from CI."
    else:
        content = "Mock reply from CI."
    return (
        'data: {"choices":[{"delta":{"content":"'
        + content
        + '"}}]}\n\n'
        "data: [DONE]\n\n"
    ).encode()


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        payload = self.rfile.read(length) if length > 0 else b""
        if self.headers.get("Authorization", "") != TOKEN:
            body = b'{"error":"unauthorized"}'
            self._send(401, "application/json", body)
            return
        path = self.path.split("?", 1)[0].rstrip("/")
        if path.endswith("/embeddings"):
            self._send(200, "application/json", embedding_body(payload))
            return
        if not path.endswith("/chat/completions"):
            body = b'{"error":"not found"}'
            self._send(404, "application/json", body)
            return
        self._send(200, "text/event-stream", reply_for(payload))

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
