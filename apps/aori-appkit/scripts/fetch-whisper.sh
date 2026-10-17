#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# whisper.cpp v1.7.6, commit a8d002cfd879315632a579e73f0148d06959de36
dest="${AORI_WHISPER_SRC:-$PWD/build/whisper.cpp}"
model="$dest/ggml-base.en.bin"
if [ ! -d "$dest/.git" ]; then
    git clone --depth 1 --branch v1.7.6 https://github.com/ggml-org/whisper.cpp.git "$dest"
fi
if [ ! -x "$dest/build/bin/whisper-cli" ]; then
    cmake -S "$dest" -B "$dest/build" -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=ON
    cmake --build "$dest/build" --target whisper-cli -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
fi
if [ ! -f "$model" ]; then
    curl -L --fail -o "$model" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
fi
mkdir -p build
cat > build/whisper.env <<EOF
AORI_WHISPER_BIN=$dest/build/bin/whisper-cli
AORI_WHISPER_MODEL=$model
EOF
echo "Wrote build/whisper.env"
