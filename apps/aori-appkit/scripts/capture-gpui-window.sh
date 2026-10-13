#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
out="$PWD/build/aori-gpui-window.png"
log="$PWD/build/aori-gpui.log"
rm -f "$out" "$log"
mkdir -p build
swift build --product AoriSceneKit
bin="$PWD/.build/debug/AoriSceneKit"
"$bin" "$out" "$PWD/Sources/AoriApp/Resources/aori-sample.vrm" >"$log" 2>&1
test -s "$out"
grep -q "aori_scenekit=vrm" "$log"
python3 scripts/check-gpui-png.py "$out"
echo "Wrote $out"
