#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
(
    cd rust
    cargo build -p aori-face
)
lib_dir="$PWD/rust/target/debug"
swift build --product AoriApp \
    -Xlinker -L -Xlinker "$lib_dir" \
    -Xlinker -laori_face
