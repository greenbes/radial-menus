#!/bin/bash

echo "Starting Radial Menu with logging..."
echo ""

# Kill any existing instances
killall radial-menu 2>/dev/null
sleep 1

# Find the app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/radial-menu-*/Build/Products/Debug -name "radial-menu.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find radial-menu.app"
    echo "Please build the app first with: xcodebuild -scheme radial-menu -configuration Debug"
    exit 1
fi

echo "App found at: $APP_PATH"
echo ""

# Launch the app
open "$APP_PATH"
APP_PID=$(pgrep -n radial-menu)

sleep 2

# Check if it's running
if [ -n "$APP_PID" ]; then
    echo "App is running (PID: $APP_PID)"
    echo "Check menu bar for the radial menu icon"
    echo "Press Ctrl+Space to open the radial menu"
    echo ""
    echo "Streaming logs (Ctrl+C to stop)..."
    echo "---"
    log stream --predicate 'subsystem == "Six-Gables-Software.radial-menu"' --level debug
else
    echo "App failed to start"
    exit 1
fi
