#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build --product AoriApp
bin_dir="$(swift build --show-bin-path)"
app_dir="build/Aori.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
cp "$bin_dir/AoriApp" "$app_dir/Contents/MacOS/AoriApp"
cp Info.plist "$app_dir/Contents/Info.plist"
for bundle in "$bin_dir"/*.bundle; do
    if [ -d "$bundle" ]; then
        cp -R "$bundle" "$app_dir/Contents/MacOS/"
    fi
done
chmod +x "$app_dir/Contents/MacOS/AoriApp"
printf 'Assembled %s\n' "$app_dir"
