#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
module_cache="$project_root/work/swift-module-cache"
iconset="$project_root/work/ModelOControl.iconset"
app="$project_root/outputs/Model O Control.app"

mkdir -p "$module_cache" "$project_root/outputs" "$project_root/work"
env CLANG_MODULE_CACHE_PATH="$module_cache" SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" \
    swift build --package-path "$project_root" --disable-sandbox --configuration release --product ModelOControl

rm -rf "$iconset"
env CLANG_MODULE_CACHE_PATH="$module_cache" swift "$project_root/scripts/render-icon.swift" \
    "$project_root/Sources/ModelOControl/Resources/model-o-icon-master.png" \
    "$iconset" \
    "$project_root/work/ModelOControl.icns"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$project_root/.build/release/ModelOControl" "$app/Contents/MacOS/ModelOControl"
cp "$project_root/work/ModelOControl.icns" "$app/Contents/Resources/ModelOControl.icns"
cp "$project_root/Sources/ModelOControl/Resources/model-o-v1-render.png" "$app/Contents/Resources/model-o-v1-render.png"
cp "$project_root/Sources/ModelOControl/Resources/model-o-sidebar-icon.png" "$app/Contents/Resources/model-o-sidebar-icon.png"
cp "$project_root/Resources/Info.plist" "$app/Contents/Info.plist"

codesign --force --deep --sign - "$app"
echo "$app"
