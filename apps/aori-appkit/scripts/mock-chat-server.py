#!/usr/bin/env python3
"""OpenAI-compatible mock. Chat text, vision images, and embeddings use one token."""

import base64
import json
import re
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


PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def vision_png(payload):
    """Return the PNG bytes, b"" when the image is bad, or None for a text chat."""
    text = payload.decode("utf-8", "replace").replace("\\/", "/")
    if "image_url" not in text:
        return None
    match = re.search(r"data:image/png;base64,([A-Za-z0-9+/=]+)", text)
    if not match:
        return b""
    try:
        raw = base64.b64decode(match.group(1), validate=False)
    except (ValueError, TypeError):
        return b""
    if len(raw) >= 8 and raw.startswith(PNG_MAGIC):
        return raw
    return b""


def chat_result(payload):
    image = vision_png(payload)
    if image is None:
        content = "Mock reply from CI."
    elif image.startswith(PNG_MAGIC):
        content = "Mock vision from CI."
    else:
        return 400, "application/json", b'{"error":"bad image"}'
    body = (
        'data: {"choices":[{"delta":{"content":"'
        + content
        + '"}}]}\n\n'
        "data: [DONE]\n\n"
    ).encode()
    return 200, "text/event-stream", body


def probe_status(header):
    if header == "error":
        return 500
    return None


def telegram_result(payload):
    try:
        body = json.loads(payload.decode("utf-8"))
    except json.JSONDecodeError:
        return 400, "application/json", b'{"ok":false}'
    text = body.get("text", "")
    if not isinstance(text, str) or not text.strip():
        return 400, "application/json", b'{"ok":false}'
    return 200, "application/json", b'{"ok":true}'


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        payload = self.rfile.read(length) if length > 0 else b""
        path = self.path.split("?", 1)[0].rstrip("/")
        if path.startswith("/bot") and path.endswith("/sendMessage"):
            status, content_type, body = telegram_result(payload)
            self._send(status, content_type, body)
            return
        if self.headers.get("Authorization", "") != TOKEN:
            body = b'{"error":"unauthorized"}'
            self._send(401, "application/json", body)
            return
        if probe_status(self.headers.get("X-Aori-Probe", "")) == 500:
            self._send(500, "application/json", b'{"error":"probe"}')
            return
        if path.endswith("/embeddings"):
            self._send(200, "application/json", embedding_body(payload))
            return
        if not path.endswith("/chat/completions"):
            body = b'{"error":"not found"}'
            self._send(404, "application/json", body)
            return
        status, content_type, body = chat_result(payload)
        self._send(status, content_type, body)

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
