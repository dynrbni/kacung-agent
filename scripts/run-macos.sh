#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Build and package bundle with embedded entitlements and Info.plist
./scripts/build.sh

# Terminate any previously running instance cleanly
killall Lafly 2>/dev/null || true

# Ensure Lafly Agent Server Daemon is running on port 3847
if ! lsof -i :3847 >/dev/null 2>&1; then
    echo "Starting Lafly Agent Daemon on port 3847..."
    (cd "$ROOT_DIR" && pnpm --filter @lafly/agent start >/tmp/lafly-agent.log 2>&1 &)
    for i in {1..20}; do
        if lsof -i :3847 >/dev/null 2>&1; then
            echo "Agent Daemon is online and listening on port 3847."
            break
        fi
        sleep 0.3
    done
else
    echo "Agent Daemon is already running on port 3847."
fi

echo "Starting Lafly macOS Assistant via LaunchServices..."
# Launch via macOS LaunchServices so TCC recognizes the app bundle and its Info.plist
open apps/macos/Lafly.app

echo "Lafly application launched successfully!"
echo "Watching logs (Press Ctrl+C to exit log watcher):"
exec /usr/bin/log stream --predicate 'process == "Lafly"' --level default
