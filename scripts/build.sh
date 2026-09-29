#!/usr/bin/env bash
set -e

echo "=== Building Kacung TypeScript Monorepo ==="
pnpm build

echo "=== Building Native macOS SwiftUI App ==="
swift build --package-path apps/macos

echo "=== Packaging Kacung.app Bundle with Info.plist & Entitlements ==="
mkdir -p apps/macos/Kacung.app/Contents/MacOS
cp apps/macos/Info.plist apps/macos/Kacung.app/Contents/Info.plist
cp apps/macos/.build/arm64-apple-macosx/debug/Kacung apps/macos/Kacung.app/Contents/MacOS/Kacung
chmod +x apps/macos/Kacung.app/Contents/MacOS/Kacung

echo "=== All Kacung components built and packaged successfully! ==="
