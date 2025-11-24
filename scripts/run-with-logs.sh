#!/bin/bash

echo "🚀 Starting Radial Menu with logging..."
echo "Log file: /tmp/radial-menu-debug.log"
echo ""

# Kill any existing instances
killall radial-menu 2>/dev/null
sleep 1

# Find the app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/radial-menu-*/Build/Products/Debug -name "radial-menu.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find radial-menu.app"
    echo "Please build the app first with: xcodebuild -scheme radial-menu -configuration Debug"
    exit 1
fi

echo "📱 App found at: $APP_PATH"
echo ""

# Run the app and redirect output
"$APP_PATH/Contents/MacOS/radial-menu" > /tmp/radial-menu-debug.log 2>&1 &
APP_PID=$!

sleep 2

# Check if it's running
if ps -p $APP_PID > /dev/null; then
    echo "✅ App is running (PID: $APP_PID)"
    echo "📋 Check menu bar for the ⊕ icon"
    echo "⌨️  Press Ctrl+Space to open the radial menu"
    echo ""
    echo "To view logs: tail -f /tmp/radial-menu-debug.log"
    echo "To stop: killall radial-menu"
else
    echo "❌ App failed to start"
    echo ""
    echo "Error output:"
    cat /tmp/radial-menu-debug.log
    exit 1
fi
