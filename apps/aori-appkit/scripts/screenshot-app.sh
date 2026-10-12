#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
app="build/Aori.app/Contents/MacOS/AoriApp"
frame="$PWD/build/aori-framebuffer.png"
window="$PWD/build/aori-window.png"
log="$PWD/build/aori-launch.log"
rm -f "$frame" "$window"
mkdir -p build
AORI_SCREENSHOT=1 AORI_FRAMEBUFFER_PATH="$frame" "$app" >"$log" 2>&1 &
pid=$!
ready=0
i=0
while [ "$i" -lt 40 ]; do
    if [ -f "$frame" ]; then
        ready=1
        break
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
        break
    fi
    i=$((i + 1))
    sleep 0.5
done
if [ "$ready" -ne 1 ]; then
    echo "The framebuffer PNG was not written."
    cat "$log" || true
    kill "$pid" 2>/dev/null || true
    exit 1
fi
python3 -c 'import pathlib,sys; data=pathlib.Path(sys.argv[1]).read_bytes(); sys.exit(0 if data.startswith(b"\x89PNG") and len(data)>1000 else 1)' "$frame"
sleep 1
cp scripts/window-id.swift /tmp/aori-window-id.swift
swiftc -o build/window-id /tmp/aori-window-id.swift
wid="$(build/window-id)"
screencapture -l "$wid" "$window"
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
test -s "$window"
echo "Wrote $frame and $window"
