#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
out="$PWD/build/aori-gpui-window.png"
log="$PWD/build/aori-gpui.log"
rm -f "$out" "$log"
mkdir -p build
cp scripts/window-id.swift /tmp/aori-window-id.swift
swiftc -o build/window-id /tmp/aori-window-id.swift
(
    cd rust
    cargo build -p aori-gpui
)
bin="$PWD/rust/target/debug/aori-gpui"
AORI_GPUI_EXIT_MS=20000 "$bin" >"$log" 2>&1 &
pid=$!
wid=""
i=0
while [ "$i" -lt 240 ]; do
    if ! kill -0 "$pid" 2>/dev/null; then
        break
    fi
    wid="$(build/window-id gpui 2>/dev/null || true)"
    if [ -n "$wid" ]; then
        break
    fi
    i=$((i + 1))
    sleep 0.5
done
if [ -z "$wid" ]; then
    echo "The GPUI window did not open."
    cat "$log" || true
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    exit 1
fi
screencapture -l "$wid" "$out"
wait "$pid" 2>/dev/null || true
test -s "$out"
grep -q "aori_gpui_window=open" "$log"
echo "Wrote $out"
