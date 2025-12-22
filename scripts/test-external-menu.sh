#!/bin/bash
#
# test-external-menu.sh
#
# Test script demonstrating external menu creation via URL scheme.
# Shows a custom menu and captures the selection.
#

set -e

SELECTION_FILE="/tmp/radial-menu-selection.txt"

# Clean up any previous selection
rm -f "$SELECTION_FILE"

# Define a custom menu as JSON
MENU_JSON='{
  "version": 1,
  "name": "Test Menu",
  "items": [
    {
      "title": "Option 1",
      "iconName": "1.circle",
      "action": { "runShellCommand": { "command": "echo Selected Option 1" } }
    },
    {
      "title": "Option 2",
      "iconName": "2.circle",
      "action": { "runShellCommand": { "command": "echo Selected Option 2" } }
    },
    {
      "title": "Option 3",
      "iconName": "3.circle",
      "action": { "runShellCommand": { "command": "echo Selected Option 3" } }
    },
    {
      "title": "Terminal",
      "iconName": "terminal",
      "action": { "launchApp": { "path": "/Applications/Utilities/Terminal.app" } }
    },
    {
      "title": "Finder",
      "iconName": "folder",
      "action": { "internalCommand": { "command": "showFinder" } }
    },
    {
      "title": "Screenshot",
      "iconName": "camera",
      "action": { "simulateKeyboardShortcut": { "modifiers": ["command", "shift"], "key": "4" } }
    }
  ]
}'

# Base64 encode the JSON for URL safety
MENU_BASE64=$(echo "$MENU_JSON" | base64 | tr -d '\n')

echo "=== External Menu Test ==="
echo ""
echo "Showing custom menu with 6 items..."
echo "Selection will be written to: $SELECTION_FILE"
echo ""

# Show the menu with returnTo to capture selection
open "radial-menu://show?json=base64:${MENU_BASE64}&returnTo=${SELECTION_FILE}&position=center"

# Wait for selection (poll the file)
echo "Waiting for selection..."
TIMEOUT=30
ELAPSED=0

while [ ! -f "$SELECTION_FILE" ] && [ $ELAPSED -lt $TIMEOUT ]; do
    sleep 0.5
    ELAPSED=$((ELAPSED + 1))
done

if [ -f "$SELECTION_FILE" ]; then
    SELECTION=$(cat "$SELECTION_FILE")
    if [ -z "$SELECTION" ]; then
        echo "Menu was dismissed without selection."
    else
        echo "Selected: $SELECTION"
    fi
    rm -f "$SELECTION_FILE"
else
    echo "Timeout waiting for selection."
fi

echo ""
echo "=== Test Complete ==="
