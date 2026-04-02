#!/bin/bash
set -e

BINARY_DIR="$HOME/.local/bin"
BINARY_PATH="$BINARY_DIR/MacIsland"
PLIST_PATH="$HOME/Library/LaunchAgents/com.aivelin.macisland.plist"

echo "Building MacIsland..."
swift build -c release

echo "Installing binary to $BINARY_PATH..."
mkdir -p "$BINARY_DIR"
cp .build/release/MacIsland "$BINARY_PATH"
chmod +x "$BINARY_PATH"

echo "Setting up LaunchAgent..."
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.aivelin.macisland</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/macisland.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/macisland.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "Done! MacIsland is running and will auto-start on login."
