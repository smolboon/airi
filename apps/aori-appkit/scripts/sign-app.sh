#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
app="build/Aori.app"
if [ ! -d "$app" ]; then
    echo "Assemble the app before signing it."
    exit 1
fi
mkdir -p build
cp Aori.entitlements build/Aori.signed.entitlements
whisper="${AORI_WHISPER_BIN:-}"
if [ -n "$whisper" ] && [ -x "$whisper" ]; then
    mac="$app/Contents/MacOS"
    cp "$whisper" "$mac/whisper-cli"
    search="$(cd "$(dirname "$whisper")/.." && pwd)"
    find "$search" \( -type f -o -type l \) \( -name '*.dylib' -o -name '*.metallib' \) -print | while IFS= read -r lib; do
        cp -L "$lib" "$mac/$(basename "$lib")"
    done
    for file in "$mac/whisper-cli" "$mac"/*.dylib; do
        if [ ! -f "$file" ]; then
            continue
        fi
        base="$(basename "$file")"
        case "$base" in
            *.dylib) install_name_tool -id "@executable_path/$base" "$file" ;;
        esac
        otool -L "$file" | awk 'NR>1 { print $1 }' | while IFS= read -r dep; do
            case "$dep" in
                /usr/lib/*|/System/*) continue ;;
            esac
            name="$(basename "$dep")"
            if [ -f "$mac/$name" ]; then
                install_name_tool -change "$dep" "@executable_path/$name" "$file"
            fi
        done
    done
    find "$mac" -maxdepth 1 -name '*.dylib' -type f -exec codesign --force --sign - {} \;
    codesign --force --sign - --entitlements AoriHelper.entitlements "$mac/whisper-cli"
    echo "aori_whisper_dylibs=bundled"
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
    "com.apple.security.files.bookmarks.app-scope",
    "com.apple.security.files.user-selected.read-write",
]
missing = [key for key in required if data.get(key) is not True]
if missing:
    print("aori_sandbox_entitlements=missing " + ",".join(missing))
    sys.exit(1)
if "com.apple.security.screen-capture" in data:
    print("aori_sandbox_screen=fake-entitlement")
    sys.exit(1)
if "com.apple.security.temporary-exception.files.absolute-path.read-write" in data:
    print("aori_sandbox_exception=checkout")
    sys.exit(1)
print("aori_sandbox_entitlements=app-sandbox,network.client,audio-input,bookmarks")
print("aori_sandbox_screen=tcc")
print("aori_sandbox_exception=absent")
PY
