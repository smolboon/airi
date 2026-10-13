#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./scripts/build-app.sh
bin_dir="$(swift build --show-bin-path)"
app_dir="build/Aori.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
cp "$bin_dir/AoriApp" "$app_dir/Contents/MacOS/AoriApp"
cp Info.plist "$app_dir/Contents/Info.plist"
mkdir -p "$app_dir/Contents/Resources"
# SwiftPM resource bundles are shallow. Contents/MacOS is for code, and codesign rejects them there.
for bundle in "$bin_dir"/*.bundle; do
    if [ -d "$bundle" ]; then
        cp -R "$bundle" "$app_dir/Contents/Resources/"
    fi
done
cp -L "../../packages/i18n/src/locales/en/aori.yaml" "$app_dir/Contents/Resources/aori.yaml"
rm -rf "$app_dir/Contents/Resources/locales"
cp -RL "../../packages/i18n/src/locales" "$app_dir/Contents/Resources/locales"
chmod +x "$app_dir/Contents/MacOS/AoriApp"
./scripts/sign-app.sh
printf 'Assembled %s\n' "$app_dir"
