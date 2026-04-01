#!/bin/bash
set -e

echo "Building MacIsland..."
swift build -c release

echo "Installing binary to /usr/local/bin..."
sudo cp .build/release/MacIsland /usr/local/bin/MacIsland
sudo chmod +x /usr/local/bin/MacIsland

echo "Setting up LaunchAgent (auto-start on login)..."
mkdir -p ~/Library/LaunchAgents
cp config/com.aivelin.macisland.plist ~/Library/LaunchAgents/

# Reload if already loaded
launchctl unload ~/Library/LaunchAgents/com.aivelin.macisland.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.aivelin.macisland.plist

echo "Done! MacIsland is running and will auto-start on login."
