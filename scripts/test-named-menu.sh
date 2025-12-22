#!/bin/bash
#
# test-named-menu.sh
#
# Test script for showing a named menu via URL scheme.
# Usage: ./test-named-menu.sh [menu-name]
#

MENU_NAME="${1:-}"
SELECTION_FILE="/tmp/radial-menu-selection.txt"

rm -f "$SELECTION_FILE"

echo "=== Named Menu Test ==="
echo ""

if [ -z "$MENU_NAME" ]; then
    echo "Showing default menu..."
    open "radial-menu://show?returnTo=${SELECTION_FILE}"
else
    echo "Showing menu: $MENU_NAME"
    open "radial-menu://show?menu=${MENU_NAME}&returnTo=${SELECTION_FILE}"
fi

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
        echo "Menu was dismissed."
    else
        echo "Selected: $SELECTION"
    fi
    rm -f "$SELECTION_FILE"
else
    echo "Timeout."
fi
