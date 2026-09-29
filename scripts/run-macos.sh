#!/usr/bin/env bash
set -e

# Build and package bundle with embedded entitlements and Info.plist
./scripts/build.sh

# Terminate any previously running instance cleanly
killall Kacung 2>/dev/null || true

echo "Starting Kacung macOS Assistant via LaunchServices..."
# Launch via macOS LaunchServices so TCC recognizes the app bundle and its Info.plist
open apps/macos/Kacung.app

echo "Kacung application launched successfully!"
echo "Watching logs (Press Ctrl+C to exit log watcher):"
exec /usr/bin/log stream --predicate 'process == "Kacung"' --level default
