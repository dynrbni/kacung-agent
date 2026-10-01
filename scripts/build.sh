#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Building Lofly TypeScript Monorepo ==="
pnpm build

echo "=== Building Native macOS SwiftUI App with Embedded Info.plist ==="
swift build --package-path apps/macos \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$ROOT_DIR/apps/macos/Info.plist"

echo "=== Packaging & Signing Lofly.app Bundle ==="
mkdir -p apps/macos/Lofly.app/Contents/MacOS
mkdir -p apps/macos/Lofly.app/Contents/Resources
cp apps/macos/Info.plist apps/macos/Lofly.app/Contents/Info.plist
if [ -f "apps/macos/AppIcon.icns" ]; then
    cp apps/macos/AppIcon.icns apps/macos/Lofly.app/Contents/Resources/AppIcon.icns
fi
cp apps/macos/.build/arm64-apple-macosx/debug/Lofly apps/macos/Lofly.app/Contents/MacOS/Lofly
chmod +x apps/macos/Lofly.app/Contents/MacOS/Lofly
codesign --force --deep --sign - apps/macos/Lofly.app

echo "=== All Lofly components built, packaged and signed successfully! ==="
