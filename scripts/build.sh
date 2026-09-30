#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Building Lafly TypeScript Monorepo ==="
pnpm build

echo "=== Building Native macOS SwiftUI App with Embedded Info.plist ==="
swift build --package-path apps/macos \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$ROOT_DIR/apps/macos/Info.plist"

echo "=== Packaging & Signing Lafly.app Bundle ==="
mkdir -p apps/macos/Lafly.app/Contents/MacOS
cp apps/macos/Info.plist apps/macos/Lafly.app/Contents/Info.plist
cp apps/macos/.build/arm64-apple-macosx/debug/Lafly apps/macos/Lafly.app/Contents/MacOS/Lafly
chmod +x apps/macos/Lafly.app/Contents/MacOS/Lafly
codesign --force --deep --sign - apps/macos/Lafly.app

echo "=== All Lafly components built, packaged and signed successfully! ==="
