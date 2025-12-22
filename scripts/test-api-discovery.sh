#!/bin/bash
#
# test-api-discovery.sh
#
# Tests the radial-menu://api and radial-menu://schema endpoints.
# Requires the radial-menu app to be running.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Temp directory for test outputs
TEMP_DIR="/tmp/radial-menu-api-test"
mkdir -p "$TEMP_DIR"

echo "=================================="
echo "Radial Menu API Discovery Test"
echo "=================================="
echo ""

# Check if app is running
if ! pgrep -x "radial-menu" > /dev/null; then
    echo -e "${YELLOW}Warning: radial-menu app is not running.${NC}"
    echo "Starting app..."
    open -a "radial-menu" 2>/dev/null || {
        # Try to find and launch from DerivedData
        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "radial-menu.app" -path "*/Debug/*" 2>/dev/null | head -1)
        if [ -n "$APP_PATH" ]; then
            open "$APP_PATH"
        else
            echo -e "${RED}Error: Could not find radial-menu.app${NC}"
            exit 1
        fi
    }
    echo "Waiting for app to start..."
    sleep 2
fi

# Test 1: API Specification
echo "Test 1: Fetching API specification..."
API_FILE="$TEMP_DIR/api-spec.json"
rm -f "$API_FILE"

open "radial-menu://api?returnTo=$API_FILE"
sleep 1

if [ -f "$API_FILE" ]; then
    echo -e "${GREEN}✓ API spec written to $API_FILE${NC}"

    # Validate JSON
    if python3 -c "import json; json.load(open('$API_FILE'))" 2>/dev/null; then
        echo -e "${GREEN}✓ Valid JSON${NC}"
    else
        echo -e "${RED}✗ Invalid JSON${NC}"
        exit 1
    fi

    # Check required fields
    echo ""
    echo "API Spec contents:"
    echo "  - apiVersion: $(jq -r '.apiVersion' "$API_FILE")"
    echo "  - appVersion: $(jq -r '.appVersion' "$API_FILE")"
    echo "  - buildID: $(jq -r '.buildID' "$API_FILE")"
    echo "  - commands: $(jq -r '.commands | keys | join(", ")' "$API_FILE")"
    echo "  - actionTypes: $(jq -r '.actionTypes | keys | join(", ")' "$API_FILE")"
    echo "  - namedMenus: $(jq -r '.namedMenus | length' "$API_FILE") menus"
    echo "  - currentMenuItems: $(jq -r '.currentMenuItems | length' "$API_FILE") items"

    # Check schemas are embedded
    if jq -e '.schemas.menuConfiguration' "$API_FILE" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ menuConfiguration schema embedded${NC}"
    else
        echo -e "${RED}✗ menuConfiguration schema missing${NC}"
    fi

    if jq -e '.schemas.menuSelectionResult' "$API_FILE" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ menuSelectionResult schema embedded${NC}"
    else
        echo -e "${RED}✗ menuSelectionResult schema missing${NC}"
    fi
else
    echo -e "${RED}✗ API spec not written${NC}"
    exit 1
fi

echo ""

# Test 2: Menu Configuration Schema
echo "Test 2: Fetching menu-configuration schema..."
SCHEMA_FILE="$TEMP_DIR/menu-configuration.schema.json"
rm -f "$SCHEMA_FILE"

open "radial-menu://schema?name=menu-configuration&returnTo=$SCHEMA_FILE"
sleep 1

if [ -f "$SCHEMA_FILE" ]; then
    echo -e "${GREEN}✓ Schema written to $SCHEMA_FILE${NC}"

    if python3 -c "import json; json.load(open('$SCHEMA_FILE'))" 2>/dev/null; then
        echo -e "${GREEN}✓ Valid JSON${NC}"
        echo "  - title: $(jq -r '.title' "$SCHEMA_FILE")"
    else
        echo -e "${RED}✗ Invalid JSON${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Schema not written (may not be bundled yet)${NC}"
fi

echo ""

# Test 3: Menu Selection Result Schema
echo "Test 3: Fetching menu-selection-result schema..."
RESULT_SCHEMA="$TEMP_DIR/menu-selection-result.schema.json"
rm -f "$RESULT_SCHEMA"

open "radial-menu://schema?name=menu-selection-result&returnTo=$RESULT_SCHEMA"
sleep 1

if [ -f "$RESULT_SCHEMA" ]; then
    echo -e "${GREEN}✓ Schema written to $RESULT_SCHEMA${NC}"

    if python3 -c "import json; json.load(open('$RESULT_SCHEMA'))" 2>/dev/null; then
        echo -e "${GREEN}✓ Valid JSON${NC}"
        echo "  - title: $(jq -r '.title' "$RESULT_SCHEMA")"
    else
        echo -e "${RED}✗ Invalid JSON${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Schema not written (may not be bundled yet)${NC}"
fi

echo ""

# Test 4: Invalid schema name
echo "Test 4: Testing invalid schema name..."
INVALID_SCHEMA="$TEMP_DIR/invalid.json"
rm -f "$INVALID_SCHEMA"

open "radial-menu://schema?name=nonexistent&returnTo=$INVALID_SCHEMA"
sleep 1

if [ ! -f "$INVALID_SCHEMA" ]; then
    echo -e "${GREEN}✓ Correctly rejected invalid schema name${NC}"
else
    echo -e "${RED}✗ Should not have written file for invalid schema${NC}"
fi

echo ""
echo "=================================="
echo "Test Summary"
echo "=================================="
echo ""
echo "Output files in: $TEMP_DIR"
echo ""
echo "To view the full API spec:"
echo "  cat $API_FILE | jq ."
echo ""
echo "To extract just commands:"
echo "  jq '.commands' $API_FILE"
echo ""
echo "To extract action types:"
echo "  jq '.actionTypes' $API_FILE"
