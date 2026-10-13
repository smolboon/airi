#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
app="build/Aori.app"
if [ ! -d "$app" ]; then
    echo "Assemble the app before signing it."
    exit 1
fi
root="$(cd ../.. && pwd)"
mkdir -p build
python3 - "$root" <<'PY'
import os
import plistlib
import sys
from pathlib import Path

root = sys.argv[1]
base = plistlib.loads(Path("Aori.entitlements").read_bytes())
base["com.apple.security.temporary-exception.files.absolute-path.read-write"] = [root]
Path("build/Aori.signed.entitlements").write_bytes(plistlib.dumps(base))
PY
whisper="${AORI_WHISPER_BIN:-}"
if [ -n "$whisper" ] && [ -x "$whisper" ]; then
    cp "$whisper" "$app/Contents/MacOS/whisper-cli"
    codesign --force --sign - --entitlements AoriHelper.entitlements "$app/Contents/MacOS/whisper-cli"
fi
codesign --force --sign - --entitlements build/Aori.signed.entitlements "$app"
codesign -d --entitlements :- "$app" > build/aori-entitlements.plist
python3 - <<'PY'
import plistlib
import sys
from pathlib import Path

raw = Path("build/aori-entitlements.plist").read_bytes()
start = raw.find(b"<?xml")
if start < 0:
    start = raw.find(b"<plist")
blob = raw[start:]
data = plistlib.loads(blob)
required = [
    "com.apple.security.app-sandbox",
    "com.apple.security.network.client",
    "com.apple.security.device.audio-input",
]
missing = [key for key in required if data.get(key) is not True]
if missing:
    print("aori_sandbox_entitlements=missing " + ",".join(missing))
    sys.exit(1)
if "com.apple.security.screen-capture" in data:
    print("aori_sandbox_screen=fake-entitlement")
    sys.exit(1)
paths = data.get("com.apple.security.temporary-exception.files.absolute-path.read-write")
if not isinstance(paths, list) or not paths:
    print("aori_sandbox_exception=missing")
    sys.exit(1)
print("aori_sandbox_entitlements=app-sandbox,network.client,audio-input")
print("aori_sandbox_screen=tcc")
print("aori_sandbox_exception=checkout")
PY
