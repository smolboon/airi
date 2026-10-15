#!/usr/bin/env python3
"""The vision mock must read the PNG. A bad image does not get the vision reply."""

import base64
import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("mock_chat_server", ROOT / "mock-chat-server.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

png = bytes.fromhex(
    "89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de"
    "0000000c4944415408d763f8cfc00000000300010005fe02fe0000000049454e44ae426082"
)
encoded = base64.b64encode(png).decode("ascii")
vision = (
    '{"messages":[{"content":[{"type":"image_url","image_url":{"url":"data:image/png;base64,'
    + encoded
    + '"}}]}]}'
).encode()
status, _, body = module.chat_result(vision)
assert status == 200, status
assert b"Mock vision from CI." in body

bad = b'{"messages":[{"content":[{"type":"image_url","image_url":{"url":"data:image/png;base64,bm90cG5n"}}]}]}'
status, _, body = module.chat_result(bad)
assert status == 400, status
assert b"Mock vision from CI." not in body

chat = b'{"messages":[{"role":"user","content":"Hello"}]}'
status, _, body = module.chat_result(chat)
assert status == 200, status
assert b"Mock reply from CI." in body
assert b"Mock vision from CI." not in body

sent, _, body = module.telegram_result(b'{"chat_id":"ci","text":"Mock reply from CI."}')
assert sent == 200, sent
assert b'"ok":true' in body
empty, _, _ = module.telegram_result(b'{"chat_id":"ci","text":""}')
assert empty == 400, empty
assert module.probe_status("error") == 500
assert module.probe_status("") is None
status, _, body = module.chat_result(chat)
assert status == 200 and b"Mock reply from CI." in body
status, _, body = module.chat_result(chat, "happy")
assert status == 200 and b"I am glad." in body and b"Mock reply from CI." not in body
status, _, body = module.chat_result(chat, "sad")
assert status == 200 and b"I am sorry." in body
status, _, body = module.chat_result(chat, "surprised")
assert status == 200 and b"Wow." in body
assert module.expression_reply("") is None
print("aori_mock_vision=ok")
