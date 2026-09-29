#!/usr/bin/env bash
set -e

# Build and package bundle with embedded entitlements and Info.plist
./scripts/build.sh

echo "Starting Kacung macOS Assistant..."
# Run the bundled application with valid Info.plist for full audio & speech entitlements
apps/macos/Kacung.app/Contents/MacOS/Kacung
