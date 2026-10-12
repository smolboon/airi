#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build --product AiriApp
bin_dir="$(swift build --show-bin-path)"
app_dir="build/Airi.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
cp "$bin_dir/AiriApp" "$app_dir/Contents/MacOS/AiriApp"
cp Info.plist "$app_dir/Contents/Info.plist"
chmod +x "$app_dir/Contents/MacOS/AiriApp"
printf 'Assembled %s\n' "$app_dir"
