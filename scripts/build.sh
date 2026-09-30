#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Building Kacung TypeScript Monorepo ==="
pnpm build

echo "=== Building Native macOS SwiftUI App with Embedded Info.plist ==="
swift build --package-path apps/macos \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$ROOT_DIR/apps/macos/Info.plist"

echo "=== Packaging & Signing Kacung.app Bundle ==="
mkdir -p apps/macos/Kacung.app/Contents/MacOS
cp apps/macos/Info.plist apps/macos/Kacung.app/Contents/Info.plist
cp apps/macos/.build/arm64-apple-macosx/debug/Kacung apps/macos/Kacung.app/Contents/MacOS/Kacung
chmod +x apps/macos/Kacung.app/Contents/MacOS/Kacung
codesign --force --deep --sign - apps/macos/Kacung.app

echo "=== All Kacung components built, packaged and signed successfully! ==="
