#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
out="$PWD/build/aori-gpui-window.png"
log="$PWD/build/aori-gpui.log"
rm -f "$out" "$log"
mkdir -p build
swift build --product AoriSceneKit
bin="$PWD/.build/debug/AoriSceneKit"
emotion=neutral
launch="$PWD/build/aori-launch.log"
if [ -f "$launch" ]; then
    found=$(grep -E '^aori_emotion=(happy|sad|surprised|neutral)$' "$launch" | tail -n 1 | cut -d= -f2 || true)
    if [ -n "$found" ]; then
        emotion=$found
    fi
fi
"$bin" "$out" "$PWD/Sources/AoriApp/Resources/aori-face.vrm" "$emotion" >"$log" 2>&1
test -s "$out"
grep -q "aori_scenekit=vrm" "$log"
grep -q "aori_scenekit_face=head" "$log"
grep -q "aori_scenekit_emotion=$emotion" "$log"
python3 scripts/check-gpui-png.py "$out"
echo "Wrote $out"
