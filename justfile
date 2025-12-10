# This list
default:
  @just --list --justfile {{justfile()}}

# Check development tools availability (text output)
check-tools:
  @uv run scripts/check_dev_tools.py --output text

# Check development tools with JSON output
check-tools-json:
  @uv run scripts/check_dev_tools.py --output json --pretty

# Internal: Quietly check tools (for use as dependency)
_check-tools-quiet:
  @echo "Checking development tools..." && \
  uv run scripts/check_dev_tools.py --output json 2>/dev/null | \
  uv run python -c "import sys, json; data=json.load(sys.stdin); sys.exit(0 if data['summary']['all_required_present'] else 1)" || \
  (echo "" && uv run scripts/check_dev_tools.py --output text && exit 1)

# Project and scheme configuration
project := "radial-menu/radial-menu.xcodeproj"
scheme := "radial-menu"

# Build the app in Debug configuration
build: _check-tools-quiet
  ./scripts/generate-build-info.sh
  xcodebuild -project {{project}} -scheme {{scheme}} -configuration Debug build

# Build the app in Release configuration
build-release: _check-tools-quiet
  ./scripts/generate-build-info.sh
  xcodebuild -project {{project}} -scheme {{scheme}} -configuration Release build

# Clean build artifacts
clean:
  xcodebuild -project {{project}} -scheme {{scheme}} clean
  rm -rf radial-menu/radial-menu/DerivedData

# Resolve package dependencies
deps: _check-tools-quiet
  xcodebuild -resolvePackageDependencies -scheme {{scheme}} -project {{project}}

# Run all tests
test: _check-tools-quiet
  xcodebuild test -project {{project}} -scheme {{scheme}}

# Run tests for a specific file (example: just test-file RadialGeometryTests)
test-file FILE: _check-tools-quiet
  xcodebuild test -project {{project}} -scheme {{scheme}} -only-testing:radial-menuTests/{{FILE}}

# Run a single test (example: just test-single RadialGeometryTests/testCalculateSlices)
test-single TEST: _check-tools-quiet
  xcodebuild test -project {{project}} -scheme {{scheme}} -only-testing:radial-menuTests/{{TEST}}

# run the app
run: 
  ./scripts/run-app.sh

# Build and run the app with logging
run-logging: build
  ./scripts/run-with-logs.sh

# Test hotkey detection with verbose logging
test-hotkey: build
  ./scripts/test-hotkey.sh

# Kill any running instances of the app
kill:
  killall radial-menu 2>/dev/null || true

# View the debug log file
logs:
  tail -f /tmp/radial-menu-debug.log

# Build, kill existing instances, and run
restart: kill build run

# Find the built app path
app-path:
  @find ~/Library/Developer/Xcode/DerivedData/radial-menu-*/Build/Products/Debug -name "radial-menu.app" -type d | head -1

# Show project info
info:
  @echo "Project: {{project}}"
  @echo "Scheme: {{scheme}}"
  @echo "App path: $(just app-path)"

# Open Xcode project
xcode:
  open {{project}}

# Archive the app for distribution
archive: _check-tools-quiet
  xcodebuild -project {{project}} -scheme {{scheme}} -configuration Release -archivePath build/radial-menu.xcarchive archive

# Export the archived app
export: archive
  xcodebuild -exportArchive -archivePath build/radial-menu.xcarchive -exportPath build -exportOptionsPlist exportOptions.plist

# Full clean including DerivedData
clean-all: clean
  rm -rf ~/Library/Developer/Xcode/DerivedData/radial-menu-*
  rm -rf build/

# Check code signing status
codesign-check:
  @APP_PATH=$(just app-path); \
  if [ -n "$$APP_PATH" ]; then \
    codesign -dv "$$APP_PATH"; \
  else \
    echo "No app found. Build first with 'just build'"; \
  fi

# Check if app has Accessibility permissions
check-permissions:
  @echo "Checking Accessibility permissions..."
  @echo "The app needs to be added to:"
  @echo "System Settings → Privacy & Security → Accessibility"
  @APP_PATH=$(just app-path); \
  if [ -n "$$APP_PATH" ]; then \
    echo ""; \
    echo "App to add: $$APP_PATH"; \
  fi

# Run linter (if SwiftLint is available)
lint:
  @if command -v swiftlint >/dev/null 2>&1; then \
    swiftlint lint --path radial-menu; \
  else \
    echo "SwiftLint not installed. Install with: brew install swiftlint"; \
  fi

# Format code (if SwiftFormat is available)
format:
  @if command -v swiftformat >/dev/null 2>&1; then \
    swiftformat radial-menu; \
  else \
    echo "SwiftFormat not installed. Install with: brew install swiftformat"; \
  fi
