#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/test-mock-vision.py
app="build/Aori.app/Contents/MacOS/AoriApp"
# The ad-hoc sandbox does not honor the checkout path exception.
# Inputs and outputs for this launch live in the app container.
box="$HOME/Library/Containers/ai.moeru.aori.appkit/Data/tmp/aori-ci"
rm -rf "$box"
mkdir -p "$box/plugins" "$box/locales"
frame="$box/aori-framebuffer.png"
window="$PWD/build/aori-window.png"
log="$PWD/build/aori-launch.log"
wav="$box/aori-speech.wav"
micwav="$box/aori-mic.wav"
visemes="$box/aori-visemes.log"
vrm="$box/aori-sample.vrm"
chat="$PWD/build/aori-chat-window.png"
memory_png="$PWD/build/aori-memory-window.png"
settings_png="$PWD/build/aori-settings-window.png"
memory_db="$box/aori-memory.sqlite"
rm -f "$window" "$chat" "$memory_png" "$settings_png"
mkdir -p build
cp -R plugins/. "$box/plugins/"
cp -RL "../../packages/i18n/src/locales/." "$box/locales/"
cp "Sources/AoriApp/Resources/aori-sample.vrm" "$vrm"
python3 - <<'PY'
import pathlib
png = bytes.fromhex(
    "89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de"
    "0000000c4944415408d763f8cfc00000000300010005fe02fe0000000049454e44ae426082"
)
pathlib.Path("build/aori-vision-fixture.png").write_bytes(png)
PY
cp build/aori-vision-fixture.png "$box/aori-vision-fixture.png"
python3 - "$micwav" <<'PY'
import math, pathlib, struct, sys
path = pathlib.Path(sys.argv[1])
rate = 16000
count = 4800
samples = [int(max(-32767, min(32767, round(0.3 * math.sin(2 * math.pi * 200 * index / rate) * 32767)))) for index in range(count)]
pcm = struct.pack("<" + "h" * count, *samples)
header = struct.pack("<4sI4s4sIHHIIHH4sI", b"RIFF", 36 + len(pcm), b"WAVE", b"fmt ", 16, 1, 1, rate, rate * 2, 2, 16, b"data", len(pcm))
path.write_bytes(header + pcm)
PY
python3 scripts/mock-chat-server.py &
mock_pid=$!
cleanup() {
    kill "$mock_pid" 2>/dev/null || true
}
trap cleanup EXIT
mock_ready=0
i=0
while [ "$i" -lt 50 ]; do
    if curl -sf -o /dev/null -X POST http://127.0.0.1:8765/v1/chat/completions \
        -H "Authorization: Bearer ci-mock-key" \
        -H "Content-Type: application/json" \
        -d '{}'; then
        mock_ready=1
        break
    fi
    i=$((i + 1))
    sleep 0.1
done
if [ "$mock_ready" -ne 1 ]; then
    echo "The mock chat server did not start."
    exit 1
fi
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
./scripts/sign-app.sh > build/aori-sign.log
if [ -x "$PWD/build/Aori.app/Contents/MacOS/whisper-cli" ]; then
    AORI_WHISPER_BIN="$PWD/build/Aori.app/Contents/MacOS/whisper-cli"
fi
if [ -n "${AORI_WHISPER_MODEL:-}" ] && [ -f "$AORI_WHISPER_MODEL" ]; then
    cp "$AORI_WHISPER_MODEL" "$box/whisper-model.bin"
    AORI_WHISPER_MODEL="$box/whisper-model.bin"
fi
cp build/aori-sign.log "$log"
AORI_SCREENSHOT=1 \
    AORI_OPENAI_API_KEY=ci-mock-key \
    AORI_OPENAI_BASE_URL=http://127.0.0.1:8765/v1 \
    AORI_OPENAI_MODEL=mock \
    AORI_CHAT_CHANNEL=telegram \
    AORI_TELEGRAM_URL=http://127.0.0.1:8765 \
    AORI_TELEGRAM_TOKEN=ci-token \
    AORI_TELEGRAM_CHAT=ci \
    AORI_PROVIDER_PROBE=1 \
    AORI_LOCALE=ja \
    AORI_LOCALES_ROOT="$box/locales" \
    AORI_FRAMEBUFFER_PATH="$frame" \
    AORI_SPEECH_WAV="$wav" \
    AORI_MIC_WAV="$micwav" \
    AORI_VISEME_LOG="$visemes" \
    AORI_VRM_PATH="$vrm" \
    AORI_AVATAR=live2d \
    AORI_PLUGINS="$box/plugins" \
    AORI_VISION_PNG="$box/aori-vision-fixture.png" \
    AORI_VISION_TICKER=1 \
    AORI_VISION_INTERVAL_MS=1000 \
    AORI_VISION_MAX_TICKS=2 \
    AORI_MEMORY_DB="$memory_db" \
    AORI_WHISPER_BIN="${AORI_WHISPER_BIN:-}" \
    AORI_WHISPER_MODEL="${AORI_WHISPER_MODEL:-}" \
    "$app" >>"$log" 2>&1 &
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
allowed = {"a", "i", "u", "e", "o", "pp", "sil"}
if not lines or any(line not in allowed for line in lines) or unique <= {"sil"}:
    sys.exit(1)
PY
python3 - "$log" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
need = [
    '"event":"frame"',
    "aori_viseme_source=audio",
    "aori_phonemes=",
    "aori_mic_source=wav",
    "aori_vad=speech",
    "aori_stt=",
    "aori_llm=",
    "aori_locale=ja",
    "aori_menu_memory=記憶",
    "aori_store=sqlite",
    "aori_settings_window=open",
    "aori_settings_pages=scene,providers,modules,card,memory,data,connection,models,system",
    "aori_locale_menu=loaded",
    "aori_stt_engine=whisper",
    "aori_stt=Hello papa",
    "aori_llm=sent",
    "aori_llm_reply=Mock reply from CI.",
    "aori_emotion=",
    "aori_chat_channel=telegram",
    "aori_telegram=sent",
    "aori_fps=",
    "aori_latency_ms=",
    "aori_memory_mb=",
    "aori_provider_error=500",
    "aori_click_through_default=off",
    "aori_click_through=on",
    "aori_click_through=delivered",
    "aori_avatar=live2d",
    "aori_plugin=loaded id=aori-greeting",
    "aori_plugin_call=aori.companion.greeting",
    "aori_plugin_result=Plugin greeting.",
    "aori_plugin_denied=aori.files.read",
    "aori_plugin=loaded id=aori-js",
    "aori_plugin_js=greeting=Plugin greeting. files=denied",
    "aori_vision_workload=screen:interpret",
    "aori_vision=sent",
    "aori_vision_reply=Mock vision from CI.",
    "aori_vision_ticker=on",
    "aori_vision_ticker=stopped",
    "aori_vision_indicator=on",
    "aori_vision_interval_ms=1000",
    "aori_vision_tick=1",
    "aori_vision_tick=2",
    "aori_memory_source=endpoint",
    "aori_embed_coreml=ok",
    "aori_embed_recall=tea",
    "aori_memory_recall=I like tea",
    "aori_memory_prompt=I like tea",
    "aori_memory_window=open",
    "aori_memory_delete=ok",
    "aori_hit_corner=pass",
    "aori_hit_body=keep",
    "aori_ignores_mouse=true",
    "aori_accessibility=Chat transcript",
    "aori_ax_press=Send message",
    "aori_mic=",
    "leftLowerArm",
    "aori_turn=done",
    "aori_window_mouth=open",
    "aori_caption=Mock reply from CI.",
    "aori_sandbox=on",
    "aori_sandbox_entitlements=app-sandbox,network.client,audio-input,bookmarks",
    "aori_sandbox_screen=tcc",
    "aori_sandbox_exception=absent",
    "aori_bookmark=ok",
]
missing = [item for item in need if item not in text]
if any(line.strip() == "aori_stt=empty" for line in text.splitlines()):
    missing.append("aori_stt=empty")
ax = [line for line in text.splitlines() if line.startswith("aori_ax=")]
ax_labels = ["Chat transcript", "Companion character", "Send message", "Companion window", "Chat window"]
if not ax or any(label not in ax[-1] for label in ax_labels):
    missing.append("aori_ax")
auth = [line.strip() for line in text.splitlines() if line.startswith("aori_stt_auth=")]
if not auth or auth[-1] not in {"aori_stt_auth=authorized", "aori_stt_auth=whisper"}:
    missing.append("aori_stt_auth")
utterance = [line.strip() for line in text.splitlines() if line.startswith("aori_mic_utterance=")]
if not utterance or utterance[-1] != "aori_mic_utterance=speech":
    missing.append("aori_mic_utterance")
permission = [line.strip() for line in text.splitlines() if line.startswith("aori_vision_permission=")]
source = [line.strip() for line in text.splitlines() if line.startswith("aori_vision_source=")]
if not permission or permission[-1] not in {"aori_vision_permission=granted", "aori_vision_permission=denied"}:
    missing.append("aori_vision_permission")
if not source or source[-1] not in {"aori_vision_source=screen", "aori_vision_source=fixture"}:
    missing.append("aori_vision_source")
if source and permission and source[-1] == "aori_vision_source=screen" and permission[-1] != "aori_vision_permission=granted":
    missing.append("aori_vision_source_without_permission")
rows = [line.strip() for line in text.splitlines() if line.startswith("aori_memory_rows=")]
if not rows or rows[-1] != "aori_memory_rows=1":
    missing.append("aori_memory_rows")
bytes_line = [line.strip() for line in text.splitlines() if line.startswith("aori_vision_bytes=")]
if not bytes_line:
    missing.append("aori_vision_bytes")
else:
    try:
        if int(bytes_line[-1].split("=", 1)[1]) <= 0:
            missing.append("aori_vision_bytes")
    except ValueError:
        missing.append("aori_vision_bytes")
print("aori_log_missing=" + ",".join(missing))
sys.exit(0 if not missing else 1)
PY
cp "$frame" build/aori-framebuffer.png
cp "$wav" build/aori-speech.wav
cp "$visemes" build/aori-visemes.log
sleep 1
cp scripts/window-id.swift /tmp/aori-window-id.swift
swiftc -o build/window-id /tmp/aori-window-id.swift
wid="$(build/window-id companion)"
screencapture -l "$wid" "$window"
chatid="$(build/window-id main || true)"
if [ -n "$chatid" ]; then
    screencapture -l "$chatid" "$chat" || true
fi
memid="$(build/window-id memory || true)"
if [ -n "$memid" ]; then
    screencapture -l "$memid" "$memory_png" || true
fi
setid="$(build/window-id settings || true)"
if [ -n "$setid" ]; then
    screencapture -l "$setid" "$settings_png" || true
fi
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
test -s "$window"
test -s "$chat"
test -s "$memory_png"
test -s "$settings_png"
voiceover="unavailable"
if open -g -a VoiceOver >/dev/null 2>&1; then
    sleep 8
    if pgrep -x VoiceOver >/dev/null 2>&1 || pgrep -f "VoiceOver.app" >/dev/null 2>&1; then
        voiceover="running"
    fi
    killall VoiceOver >/dev/null 2>&1 || true
fi
echo "aori_voiceover=$voiceover" >>"$log"
python3 - "$log" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
marks = [line.strip() for line in text.splitlines() if line.startswith("aori_voiceover=")]
allowed = {"aori_voiceover=running", "aori_voiceover=unavailable"}
sys.exit(0 if marks and marks[-1] in allowed else 1)
PY
echo "Wrote $frame, $window, and $chat"
