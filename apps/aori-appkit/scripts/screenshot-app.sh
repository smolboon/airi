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
chat="$PWD/build/aori-chat-window.png"
rm -f "$frame" "$window" "$chat" "$wav" "$visemes"
mkdir -p build
prepare_keychain() {
    chain="$HOME/Library/Keychains/aori-ci.keychain-db"
    security delete-keychain "$chain" 2>/dev/null || true
    security create-keychain -p aori-ci "$chain"
    security set-keychain-settings -lut 21600 "$chain"
    security unlock-keychain -p aori-ci "$chain"
    security list-keychains -d user -s "$chain"
    security default-keychain -s "$chain"
}
if ! prepare_keychain; then
    echo "aori_keychain_setup=failed"
fi
if [ -f build/whisper.env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./build/whisper.env
    set +a
fi
AORI_SCREENSHOT=1 \
    AORI_LOCALE=ja \
    AORI_LOCALES_ROOT="$PWD/../../packages/i18n/src/locales" \
    AORI_FRAMEBUFFER_PATH="$frame" \
    AORI_SPEECH_WAV="$wav" \
    AORI_VISEME_LOG="$visemes" \
    AORI_VRM_PATH="$vrm" \
    AORI_WHISPER_BIN="${AORI_WHISPER_BIN:-}" \
    AORI_WHISPER_MODEL="${AORI_WHISPER_MODEL:-}" \
    "$app" >"$log" 2>&1 &
pid=$!
ready=0
i=0
while [ "$i" -lt 200 ]; do
    if [ -f "$frame" ] && [ -f "$wav" ] && [ -f "$visemes" ] && grep -q "aori_turn=done" "$log"; then
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
unique = set(lines)
print("aori_viseme_presets=" + ",".join(sorted(unique)))
needed = {"e", "o", "a", "pp"}
sys.exit(0 if needed.issubset(unique) else 1)
PY
python3 - "$log" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
need = [
    '"event":"frame"',
    "aori_phonemes=HH,EH,L,OW,P,AA,P,AH",
    "aori_vad=speech",
    "aori_stt=",
    "aori_llm=",
    "aori_locale=ja",
    "aori_locale_menu=loaded",
    "aori_stt_engine=whisper",
    "aori_stt=Hello papa",
    "aori_llm=local",
    "aori_click_through=on",
    "aori_hit_corner=pass",
    "aori_hit_body=keep",
    "aori_ignores_mouse=true",
    "aori_accessibility=Chat transcript",
    "aori_mic=",
    "leftLowerArm",
    "aori_turn=done",
]
missing = [item for item in need if item not in text]
if any(line.strip() == "aori_stt=empty" for line in text.splitlines()):
    missing.append("aori_stt=empty")
print("aori_log_missing=" + ",".join(missing))
sys.exit(0 if not missing else 1)
PY
sleep 1
cp scripts/window-id.swift /tmp/aori-window-id.swift
swiftc -o build/window-id /tmp/aori-window-id.swift
wid="$(build/window-id companion)"
screencapture -l "$wid" "$window"
chatid="$(build/window-id main || true)"
if [ -n "$chatid" ]; then
    screencapture -l "$chatid" "$chat" || true
fi
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
test -s "$window"
test -s "$chat"
echo "Wrote $frame, $window, and $chat"
