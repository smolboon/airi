#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
python3 scripts/test-mock-vision.py
python3 scripts/mock-chat-server.py &
mock_pid=$!
trap 'kill "$mock_pid" 2>/dev/null || true' EXIT
ready=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf -o /dev/null -X POST http://127.0.0.1:8765/v1/chat/completions \
        -H "Authorization: Bearer ci-mock-key" \
        -H "Content-Type: application/json" \
        -d '{"messages":[{"role":"user","content":"Hello"}]}'; then
        ready=1
        break
    fi
    sleep 0.2
done
test "$ready" = 1
swift build --product AoriSceneKit
bin="$PWD/.build/debug/AoriSceneKit"
vrm="$PWD/Sources/AoriApp/Resources/aori-face.vrm"
for kind in happy sad surprised; do
    reply=$(curl -sf -X POST http://127.0.0.1:8765/v1/chat/completions \
        -H "Authorization: Bearer ci-mock-key" \
        -H "X-Aori-Expression: $kind" \
        -H "Content-Type: application/json" \
        -d '{"messages":[{"role":"user","content":"Hello"}]}' \
        | python3 -c 'import json,sys; text=sys.stdin.read(); line=[item for item in text.splitlines() if item.startswith("data: {")][0]; print(json.loads(line[6:])["choices"][0]["delta"]["content"])')
    out="$PWD/build/aori-face-$kind.png"
    log="$PWD/build/aori-face-$kind.log"
    "$bin" "$out" "$vrm" --reply "$reply" >"$log" 2>&1
    grep -q "aori_scenekit_emotion=$kind" "$log"
    grep -q "aori_expression_reply=$reply" "$log"
    python3 scripts/check-gpui-png.py "$out"
    echo "aori_expression_face=$kind reply=$reply"
done
