#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
app="build/Aori.app/Contents/MacOS/AoriApp"
frame="$PWD/build/aori-framebuffer.png"
window="$PWD/build/aori-window.png"
log="$PWD/build/aori-launch.log"
wav="$PWD/build/aori-speech.wav"
visemes="$PWD/build/aori-visemes.log"
vrm="$PWD/Sources/AoriApp/Resources/aori-sample.vrm"
rm -f "$frame" "$window" "$wav" "$visemes"
mkdir -p build
AORI_SCREENSHOT=1 \
    AORI_FRAMEBUFFER_PATH="$frame" \
    AORI_SPEECH_WAV="$wav" \
    AORI_VISEME_LOG="$visemes" \
    AORI_VRM_PATH="$vrm" \
    "$app" >"$log" 2>&1 &
pid=$!
ready=0
i=0
while [ "$i" -lt 80 ]; do
    if [ -f "$frame" ] && [ -f "$wav" ] && [ -f "$visemes" ]; then
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
    echo "The framebuffer, speech WAV, or viseme log was not written."
    cat "$log" || true
    kill "$pid" 2>/dev/null || true
    exit 1
fi
python3 -c 'import pathlib,sys; data=pathlib.Path(sys.argv[1]).read_bytes(); sys.exit(0 if data.startswith(b"\x89PNG") and len(data)>1000 else 1)' "$frame"
python3 - "$wav" <<'PY'
import pathlib, struct, sys
data = pathlib.Path(sys.argv[1]).read_bytes()
if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
    sys.exit(1)
offset = 12
samples = None
while offset + 8 <= len(data):
    tag = data[offset:offset + 4]
    size = struct.unpack_from("<I", data, offset + 4)[0]
    if tag == b"data":
        samples = data[offset + 8:offset + 8 + size]
        break
    offset += 8 + size
if not samples or len(samples) < 2:
    sys.exit(1)
count = len(samples) // 2
values = struct.unpack("<" + "h" * count, samples[:count * 2])
rms = (sum(value * value for value in values) / count) ** 0.5 / 32767
print(f"aori_wav_rms={rms:.4f}")
sys.exit(0 if rms > 0.01 else 1)
PY
python3 - "$visemes" <<'PY'
import pathlib, sys
lines = [line.strip() for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if line.strip()]
unique = sorted(set(lines))
print("aori_viseme_presets=" + ",".join(unique))
sys.exit(0 if len(unique) > 1 else 1)
PY
sleep 1
cp scripts/window-id.swift /tmp/aori-window-id.swift
swiftc -o build/window-id /tmp/aori-window-id.swift
wid="$(build/window-id)"
screencapture -l "$wid" "$window"
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
test -s "$window"
echo "Wrote $frame and $window"
