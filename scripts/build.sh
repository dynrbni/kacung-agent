#!/usr/bin/env bash
set -e

echo "=== Building Kacung TypeScript Monorepo ==="
pnpm build

echo "=== Building Native macOS SwiftUI App ==="
swift build --package-path apps/macos

echo "=== All Kacung components built successfully! ==="
