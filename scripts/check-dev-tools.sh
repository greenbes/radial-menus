#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔍 Development Tools Check for Radial Menu"
echo "==========================================="
echo ""

# Track if all required tools are installed
ALL_REQUIRED=true

# Function to check if a command exists
check_command() {
    local cmd=$1
    local name=$2
    local required=$3
    local install_hint=$4
    local version_flag=${5:---version}

    echo -n "Checking $name... "

    if command -v $cmd &> /dev/null; then
        # Get version info
        if [ "$version_flag" = "--version" ]; then
            version=$($cmd --version 2>&1 | head -1)
        elif [ "$version_flag" = "-v" ]; then
            version=$($cmd -v 2>&1 | head -1)
        elif [ "$version_flag" = "version" ]; then
            version=$($cmd version 2>&1 | head -1)
        else
            version=$($cmd $version_flag 2>&1 | head -1)
        fi

        echo -e "${GREEN}✓${NC} Found"
        echo "  └─ $version"
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗${NC} Not found (REQUIRED)"
            ALL_REQUIRED=false
        else
            echo -e "${YELLOW}⚠${NC} Not found (optional)"
        fi
        echo "  └─ Install: $install_hint"
    fi
    echo ""
}

echo -e "${BLUE}Required Tools:${NC}"
echo "---------------"

# Check for Xcode Command Line Tools
echo -n "Checking Xcode Command Line Tools... "
if xcode-select -p &> /dev/null; then
    xcode_path=$(xcode-select -p)
    echo -e "${GREEN}✓${NC} Found"
    echo "  └─ Path: $xcode_path"
else
    echo -e "${RED}✗${NC} Not found (REQUIRED)"
    echo "  └─ Install: xcode-select --install"
    ALL_REQUIRED=false
fi
echo ""

# Check for full Xcode installation (not just Command Line Tools)
echo -n "Checking Xcode... "
XCODE_APP="/Applications/Xcode.app"
XCODE_SELECT_PATH=$(xcode-select -p 2>/dev/null)

if [ -d "$XCODE_APP" ]; then
    # Xcode.app exists, check if it's selected
    if [[ "$XCODE_SELECT_PATH" == *"Xcode.app"* ]]; then
        version=$(xcodebuild -version 2>/dev/null | head -1)
        echo -e "${GREEN}✓${NC} Found"
        echo "  └─ $version"
        echo "  └─ Path: $XCODE_SELECT_PATH"

        # Check if Xcode needs first launch setup
        if ! xcodebuild -checkFirstLaunchStatus &> /dev/null; then
            echo -e "  └─ ${YELLOW}Warning:${NC} Xcode may need to complete first launch setup"
            echo "      Run: sudo xcodebuild -runFirstLaunch"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Found but not selected"
        echo "  └─ Xcode.app exists at $XCODE_APP"
        echo "  └─ Current selection: $XCODE_SELECT_PATH"
        echo "  └─ Fix: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        ALL_REQUIRED=false
    fi
elif [[ "$XCODE_SELECT_PATH" == "/Library/Developer/CommandLineTools" ]]; then
    echo -e "${RED}✗${NC} Not found (REQUIRED)"
    echo "  └─ Only Command Line Tools installed"
    echo "  └─ Install: Download Xcode from Mac App Store or https://developer.apple.com"
    ALL_REQUIRED=false
else
    echo -e "${RED}✗${NC} Not found (REQUIRED)"
    echo "  └─ Install: Download Xcode from Mac App Store or https://developer.apple.com"
    ALL_REQUIRED=false
fi
echo ""

# Check for xcodebuild (should work if Xcode is properly installed)
echo -n "Checking xcodebuild... "
if xcodebuild -version &> /dev/null; then
    version=$(xcodebuild -version | head -1)
    echo -e "${GREEN}✓${NC} Found and working"
    echo "  └─ $version"
else
    echo -e "${RED}✗${NC} Not working (REQUIRED)"
    if command -v xcodebuild &> /dev/null; then
        echo "  └─ Command exists but fails to run"
        echo "  └─ This usually means Xcode.app is not installed or not selected"
        echo "  └─ Run: xcode-select -p to see current selection"
    else
        echo "  └─ Command not found"
    fi
    ALL_REQUIRED=false
fi
echo ""

# Check for Swift
check_command "swift" "Swift" "true" "Comes with Xcode"

# Check for Git
check_command "git" "Git" "true" "xcode-select --install or brew install git"

# Check for just (command runner)
check_command "just" "Just (command runner)" "true" "brew install just or cargo install just"

echo -e "${BLUE}Optional Tools:${NC}"
echo "---------------"

# Check for Homebrew
check_command "brew" "Homebrew" "false" "Visit https://brew.sh for installation"

# Check for SwiftLint
check_command "swiftlint" "SwiftLint" "false" "brew install swiftlint"

# Check for SwiftFormat
check_command "swiftformat" "SwiftFormat" "false" "brew install swiftformat"

# Check for rsvg-convert (for icon conversion)
check_command "rsvg-convert" "rsvg-convert (for SVG→PDF)" "false" "brew install librsvg"

# Check for gh (GitHub CLI - useful for PR creation mentioned in justfile)
check_command "gh" "GitHub CLI" "false" "brew install gh" "version"

# Check for jq (useful for JSON manipulation with config files)
check_command "jq" "jq (JSON processor)" "false" "brew install jq"

echo -e "${BLUE}Project-Specific Checks:${NC}"
echo "------------------------"

# Check for GameController framework availability
echo -n "Checking GameController framework... "
if [ -d "/System/Library/Frameworks/GameController.framework" ] || \
   [ -d "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/GameController.framework" ]; then
    echo -e "${GREEN}✓${NC} Found"
else
    echo -e "${YELLOW}⚠${NC} Not found (needed for controller support)"
fi
echo ""

# Check macOS version (project may have minimum requirements)
echo -n "Checking macOS version... "
macos_version=$(sw_vers -productVersion)
echo -e "${GREEN}✓${NC} $macos_version"

# Parse major version
major_version=$(echo $macos_version | cut -d. -f1)
if [ "$major_version" -lt 13 ]; then
    echo -e "  └─ ${YELLOW}Warning:${NC} macOS 13.0+ recommended for latest SwiftUI features"
fi
echo ""

# Check if running on Apple Silicon or Intel
echo -n "Checking architecture... "
arch=$(uname -m)
if [ "$arch" = "arm64" ]; then
    echo -e "${GREEN}✓${NC} Apple Silicon (arm64)"
else
    echo -e "${GREEN}✓${NC} Intel (x86_64)"
fi
echo ""

echo "==========================================="
echo ""

# Summary
if [ "$ALL_REQUIRED" = true ]; then
    echo -e "${GREEN}✅ All required tools are installed!${NC}"
    echo ""
    echo "You can now build the project with:"
    echo "  just build"
    echo ""
    echo "Or run it with:"
    echo "  just run"
else
    echo -e "${RED}❌ Some required tools are missing.${NC}"
    echo ""
    echo "Please install the missing required tools before proceeding."
    echo ""
    echo "Quick setup for most tools:"
    echo "  1. Install Xcode from the Mac App Store"
    echo "  2. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "  3. Install just: brew install just"
    exit 1
fi

# Check for Accessibility permissions hint
echo ""
echo -e "${YELLOW}📝 Remember:${NC}"
echo "The app needs Accessibility permissions for global hotkeys to work."
echo "Grant access in: System Settings → Privacy & Security → Accessibility"