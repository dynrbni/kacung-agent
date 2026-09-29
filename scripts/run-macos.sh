#!/usr/bin/env bash
set -e

# Ensure bundle exists
if [ ! -f "apps/macos/Kacung.app/Contents/MacOS/Kacung" ]; then
    echo "Kacung.app bundle not found. Building now..."
    ./scripts/build.sh
fi

echo "Starting Kacung macOS Assistant..."
# Run the bundled application with valid Info.plist for full audio & speech entitlements
apps/macos/Kacung.app/Contents/MacOS/Kacung
