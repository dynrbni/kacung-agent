#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Build and package bundle with embedded entitlements and Info.plist
./scripts/build.sh

# Terminate any previously running instance cleanly
killall Lofly 2>/dev/null || true
lsof -ti:3847 | xargs kill -9 2>/dev/null || true
sleep 0.5

# Ensure Lofly Agent Server Daemon is running on port 3847
echo "Starting Lofly Agent Daemon on port 3847 with LIVE execution mode..."
(cd "$ROOT_DIR/apps/agent" && nohup node dist/server.js >/tmp/lofly-agent.log 2>&1 &)
for i in {1..20}; do
    if lsof -i :3847 >/dev/null 2>&1; then
        echo "Agent Daemon is online and listening on port 3847."
        break
    fi
    sleep 0.3
done

echo "Starting Lofly macOS Assistant via LaunchServices..."
# Launch via macOS LaunchServices so TCC recognizes the app bundle and its Info.plist
open apps/macos/Lofly.app

echo "Lofly application launched successfully!"
echo "Watching logs (Press Ctrl+C to exit log watcher):"
exec /usr/bin/log stream --predicate 'process == "Lofly"' --level default
