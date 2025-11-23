#!/bin/bash

echo "🧪 Radial Menu Hotkey Test"
echo "=========================="
echo ""
echo "This script will run the app and show all log messages."
echo "You can see exactly what happens when you press Ctrl+Space."
echo ""

# Kill any existing instances
killall radial-menu 2>/dev/null
sleep 1

# Find the app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/radial-menu-*/Build/Products/Debug -name "radial-menu.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find radial-menu.app"
    echo "Please build the app first"
    exit 1
fi

echo "📱 Found app at: $APP_PATH"
echo ""
echo "🚀 Starting app with logging..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run the app and display output
"$APP_PATH/Contents/MacOS/radial-menu" 2>&1 | while IFS= read -r line; do
    echo "$line"

    # Highlight important messages
    if [[ "$line" == *"HOTKEY EVENT RECEIVED"* ]]; then
        echo ""
        echo "✨✨✨ HOTKEY WAS DETECTED! ✨✨✨"
        echo ""
    fi

    if [[ "$line" == *"Failed to register hotkey"* ]]; then
        echo ""
        echo "⚠️⚠️⚠️  PERMISSION ISSUE DETECTED  ⚠️⚠️⚠️"
        echo ""
        echo "You need to grant Accessibility permissions:"
        echo "1. Open System Settings"
        echo "2. Go to Privacy & Security → Accessibility"
        echo "3. Click the '+' button"
        echo "4. Add radial-menu.app"
        echo "5. Restart this script"
        echo ""
    fi
done &

APP_PID=$!

sleep 3

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ App is running!"
echo ""
echo "📋 Next steps:"
echo "   1. Look for the ⊕ icon in your menu bar"
echo "   2. Press Ctrl+Space"
echo "   3. Watch the log output above"
echo ""
echo "Expected log messages when you press Ctrl+Space:"
echo "   🔥 HotkeyManager: HOTKEY EVENT RECEIVED!"
echo "   🎯 RadialMenuViewModel: toggleMenu() called"
echo "   🎯 RadialMenuViewModel: Opening menu..."
echo ""
echo "To stop the app: Press Ctrl+C"
echo ""

# Wait for the app process
wait $APP_PID
