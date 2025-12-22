# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Radial Menu is a macOS menu bar application that displays a configurable radial overlay menu triggered by hotkey, controller, mouse, or keyboard. The app follows Clean Architecture with Functional Core / Imperative Shell pattern and SOLID principles.

## Build & Run Commands

### Building

```bash
# Resolve dependencies (if needed)
xcodebuild -resolvePackageDependencies -scheme radial-menu -project radial-menu/radial-menu.xcodeproj

# Generate build info (includes git commit hash and timestamp)
./scripts/generate-build-info.sh

# Build Debug (uses system DerivedData location)
xcodebuild -project radial-menu/radial-menu.xcodeproj -scheme radial-menu -configuration Debug build

# Build Release
xcodebuild -project radial-menu/radial-menu.xcodeproj -scheme radial-menu -configuration Release build

# Combined: generate build info and build
./scripts/generate-build-info.sh && xcodebuild -project radial-menu/radial-menu.xcodeproj -scheme radial-menu -configuration Debug build

# Note: If you encounter "Multiple commands produce" errors, remove any local DerivedData:
# rm -rf radial-menu/radial-menu/DerivedData
```

### Build Identification

Each build includes a unique build ID generated from git metadata:

- **Build ID**: Short commit hash + "-dirty" suffix if uncommitted changes exist
- **Generated file**: `BuildInfo.generated.swift` (auto-generated, git-ignored)
- **Access in code**: `BuildInfo.buildID`, `BuildInfo.commitHash`, `BuildInfo.branch`
- **Visible in app**: Menu bar → About Radial Menu

### Running

```bash
# Launch with logging (finds latest Debug build, streams system log)
./scripts/run-with-logs.sh

# Test hotkey detection with verbose logging
./scripts/test-hotkey.sh

# Kill running instances
killall radial-menu
```

### Testing

```bash
# Run all tests
xcodebuild test -scheme radial-menu

# Run specific test file
xcodebuild test -scheme radial-menu -only-testing:radial-menuTests/RadialGeometryTests

# Run single test
xcodebuild test -scheme radial-menu -only-testing:radial-menuTests/RadialGeometryTests/testCalculateSlices
```

## Architecture

The codebase follows **Clean Architecture** with strict layer separation and the **Functional Core / Imperative Shell** pattern.

### Layer Structure

```
Domain/          - Pure business logic (no framework dependencies)
  Models/        - MenuItem, MenuConfiguration, ActionType, MenuState
                   IconSetDefinition, IconSetDescriptor, ResolvedIcon
  Geometry/      - Pure functions: RadialGeometry, HitDetector, SelectionCalculator
  IconResolution/- Pure icon resolution: IconResolver

Infrastructure/  - System integration via protocols
  Input/         - HotkeyManager, ControllerInputManager, EventMonitor
  Window/        - OverlayWindowController, RadialMenuContainerView
  Actions/       - ActionExecutor (launch apps, run commands, keyboard shortcuts)
  Configuration/ - ConfigurationManager (JSON persistence)
  IconSets/      - IconSetProvider, IconSetValidator, BuiltInIconSets
  Accessibility/ - AccessibilityManager, AccessibleSliceElement
  ExternalRequests/ - ExternalRequestHandler (unified external API)
  Shortcuts/     - App Intents, Entities, ShortcutsServiceLocator
  Scripting/     - AppleScript commands and scriptable classes
  URLScheme/     - URL scheme handler with x-callback-url support
  Menus/         - MenuProvider for resolving menu sources

Presentation/    - SwiftUI views + ViewModels (MVVM)
  RadialMenu/    - RadialMenuView, SliceView, RadialMenuViewModel
  Preferences/   - PreferencesView, IconSetImportView
  MenuBar/       - MenuBarController

Root/            - App coordination
  AppCoordinator - Composition root, dependency injection
  AppDelegate    - Minimal delegate
```

### Key Architectural Patterns

1. **Protocol-Oriented Design**: All infrastructure components implement protocols (e.g., `ConfigurationManagerProtocol`, `ActionExecutorProtocol`, `IconSetProviderProtocol`) for testability and dependency injection
2. **Dependency Injection**: Constructor injection throughout, all dependencies wired in `AppCoordinator`
3. **Pure Functions in Domain**: Geometry calculations and icon resolution are side-effect-free, deterministic functions
4. **State Machine**: Menu lifecycle follows clear state transitions (Closed → Opening → Open → Executing → Closing)
5. **MVVM in Presentation**: Views bind to `@ObservableObject` ViewModels
6. **Combine-based Reactivity**: Configuration changes propagate via publishers (`configurationPublisher`, `iconSetsPublisher`)

### Data Flow

```
User Input (Hotkey/Controller/Mouse/Keyboard)
    ↓
Input Manager (Infrastructure) - HotkeyManager, ControllerInputManager
    ↓
ViewModel (Presentation) - RadialMenuViewModel
    ↓
Geometry Calculator (Domain) - Pure functions
    ↓
Icon Resolution (Domain) - IconResolver via IconSetProvider
    ↓
ViewModel Updates State (@Published)
    ↓
View Renders (SwiftUI) - SliceView with ResolvedIcon
    ↓
User Confirms Selection
    ↓
ActionExecutor (Infrastructure) - Launch app, run command, keyboard shortcut
    ↓
AccessibilityManager (Infrastructure) - VoiceOver announcements
```

## Configuration & Storage

### User Configuration

Configuration persists as JSON at:
```
~/Library/Application Support/Six-Gables-Software.radial-menu/radial-menu-config.json
```

### User Icon Sets

User-imported icon sets are stored at:
```
~/Library/Application Support/Six-Gables-Software.radial-menu/icon-sets/<identifier>/
```

Each icon set directory contains a `manifest.json` and an `icons/` subdirectory.

### App-Specific Menus

App-specific menus allow different menu configurations for different applications. When the right shoulder button (RB/R1) is pressed, the app detects which application has keyboard focus and displays a menu tailored to that application.

**Storage**: App-specific menus are stored as named menus using the application's bundle identifier as the filename:
```
~/Library/Application Support/Six-Gables-Software.radial-menu/menus/<bundleID>.json
```

**Example**: A menu for Firefox would be stored at:
```
~/Library/Application Support/Six-Gables-Software.radial-menu/menus/org.mozilla.firefox.json
```

**Fallback**: If no app-specific menu exists for the frontmost application, the default menu is displayed.

**Navigation** (Ring):

Menus are linked in a ring. Shoulder buttons cycle between default and app-specific menus:

- Right shoulder (RB/R1): Switch to next menu in ring (default ↔ app-specific)
- Left shoulder (LB/L1): Switch to previous menu in ring (default ↔ app-specific)
- B button: Close menu

**Example app-specific menu** (`org.mozilla.firefox.json`):
```json
{
  "version": 1,
  "name": "org.mozilla.firefox",
  "description": "Firefox browser shortcuts",
  "centerTitle": "Firefox",
  "items": [
    {
      "title": "New Tab",
      "iconName": "plus",
      "action": { "simulateKeyboardShortcut": { "modifiers": ["command"], "key": "t" } }
    },
    {
      "title": "Close Tab",
      "iconName": "xmark",
      "action": { "simulateKeyboardShortcut": { "modifiers": ["command"], "key": "w" } }
    },
    {
      "title": "Go Back",
      "iconName": "arrow.left",
      "action": { "simulateKeyboardShortcut": { "modifiers": ["command"], "key": "[" } }
    },
    {
      "title": "Go Forward",
      "iconName": "arrow.right",
      "action": { "simulateKeyboardShortcut": { "modifiers": ["command"], "key": "]" } }
    },
    {
      "title": "Reload",
      "iconName": "arrow.clockwise",
      "action": { "simulateKeyboardShortcut": { "modifiers": ["command"], "key": "r" } }
    },
    {
      "title": "Find",
      "iconName": "magnifyingglass",
      "action": { "simulateKeyboardShortcut": { "modifiers": ["command"], "key": "f" } }
    }
  ]
}
```

**Finding bundle identifiers**: Use `osascript -e 'id of app "App Name"'` or check the app's Info.plist.

### Default Configuration

Default menu items and settings are defined in `MenuConfiguration.sample()` (Domain/Models/MenuConfiguration.swift:172-221):
- 8 sample items: Terminal, Safari, Screenshot, Mute, Calendar, Notes, Reminders, Files
- Icon set identifier: "outline" (configurable via Preferences)
- Position mode: At cursor
- Radius: 150.0, Center radius: 40.0

### Logging

The app uses Apple's Unified Logging System (os_log) with category-specific log functions defined in `Logger.swift`:

- `LogLifecycle()` - App startup, shutdown, coordinator events
- `LogInput()` - Hotkey, keyboard, mouse, controller input
- `LogMenu()` - Menu state changes, selection
- `LogWindow()` - Window management, positioning
- `LogGeometry()` - Hit detection, angle calculations
- `LogAction()` - Action execution
- `LogConfig()` - Configuration loading/saving
- `LogShortcuts()` - Shortcuts, App Intents, AppleScript, URL scheme
- `LogError()` - Errors (specify category)

**Viewing logs:**

Logs are stored in the macOS unified system log (not a file). Use `log` commands to access them:

```bash
# Stream logs in real-time
log stream --predicate 'subsystem == "Six-Gables-Software.radial-menu"' --level debug

# View recent logs (last 5 minutes)
log show --predicate 'subsystem == "Six-Gables-Software.radial-menu"' --last 5m

# Filter by category
log show --predicate 'subsystem == "Six-Gables-Software.radial-menu" AND category == "Input"' --last 5m

# Or use the helper script (streams logs)
./scripts/run-with-logs.sh
```

**IMPORTANT**: Debug-level logs are NOT persisted to the system log. To capture debug logs, use `log stream` in a background task and read the output file after testing. For Info-level and above, use `log show`.

**IMPORTANT**: Do NOT use `print()` statements. Always use the appropriate category log function.

## Input Handling

### Global Hotkey

- **Default**: Ctrl + Space
- **Implementation**: Carbon Event Manager via `HotkeyManager`
- **Permissions**: Requires Accessibility permissions (System Settings → Privacy & Security → Accessibility)
- **Registration**: In `AppCoordinator.start()` at AppCoordinator.swift:60-73

### Controller Support

- **Supported**: Xbox, PlayStation, MFi controllers
- **Input mapping**:

    - Left stick → Selection
    - Right stick → Reposition menu
    - A button → Confirm
    - B button → Close menu
    - Menu button → Toggle default menu
    - Right shoulder (RB/R1) → Cycle to next menu in ring (default ↔ app-specific)
    - Left shoulder (LB/L1) → Cycle to previous menu in ring (default ↔ app-specific)
    - D-pad left/right → Navigate slices

- **Polling rate**: 60Hz
- **Implementation**: GameController framework via `ControllerInputManager`

### Mouse

- Move to select slice
- Click to confirm
- Click outside to dismiss (with click-through to underlying apps)

### Keyboard

- Right Arrow: Select next slice clockwise
- Left Arrow: Select previous slice counter-clockwise
- Escape: Close menu without action

## External API

The app accepts requests from external programs via URL scheme, Apple Shortcuts, and AppleScript. All interfaces use a unified `ExternalRequestHandler` to ensure consistent behavior.

### URL Scheme

The `radial-menu://` URL scheme allows shell scripts and other apps to control the menu.

**Commands:**

| URL | Description |
|-----|-------------|
| `radial-menu://show` | Show the default menu |
| `radial-menu://show?menu=<name>` | Show a named menu |
| `radial-menu://show?file=<path>` | Show menu from JSON file |
| `radial-menu://show?json=<json>` | Show menu from inline JSON |
| `radial-menu://show?json=base64:<b64>` | Show menu from base64-encoded JSON |
| `radial-menu://hide` | Hide the menu |
| `radial-menu://toggle` | Toggle menu visibility |
| `radial-menu://execute?item=<uuid>` | Execute item by UUID |
| `radial-menu://execute?title=<title>` | Execute item by title |
| `radial-menu://api?returnTo=<path>` | Get API specification (self-describing) |
| `radial-menu://schema?name=<name>&returnTo=<path>` | Get JSON schema by name |

**Parameters:**

| Parameter | Values | Description |
|-----------|--------|-------------|
| `position` | `cursor`, `center`, `x,y` | Menu position (default: cursor) |
| `returnTo` | File path | Write selection to file (disables action) |
| `x-success` | URL | Callback on selection (adds `selected`, `id`, `position`, `actionType`) |
| `x-error` | URL | Callback on error (adds `errorMessage`) |
| `x-cancel` | URL | Callback when dismissed |

**Examples:**

```bash
# Show menu at screen center
open "radial-menu://show?position=center"

# Show menu with x-callback-url
open "radial-menu://show?x-success=myapp://selected&x-cancel=myapp://cancelled"

# Show named menu, write selection to file
open "radial-menu://show?menu=development&returnTo=/tmp/selection.txt"

# Execute item by title
open "radial-menu://execute?title=Terminal"

# Get API specification (for programmatic discovery)
open "radial-menu://api?returnTo=/tmp/api-spec.json"

# Get specific schema
open "radial-menu://schema?name=menu-configuration&returnTo=/tmp/schema.json"
```

**API Discovery:**

The `api` command returns a self-describing JSON specification containing:

- All available commands with parameters and examples
- Action types with format examples
- Full JSON schemas embedded inline
- Currently available named menus
- Current menu items in default configuration

Available schemas via the `schema` command:

- `menu-configuration` - Input format for menu definitions
- `menu-selection-result` - Output format for selection results
- `api-spec` - Structure of the API specification itself

### Apple Shortcuts

The app provides App Intents for the Shortcuts app:

| Intent | Description |
|--------|-------------|
| Show Menu | Show the default menu |
| Show Named Menu | Show a saved menu (with picker UI) |
| Show Custom Menu | Show menu from JSON definition |
| Get Menu Items | List current menu items |
| Get Named Menus | List available named menus |
| Execute Menu Item | Execute an item by title |
| Toggle Menu | Toggle menu visibility |
| Add Menu Item | Add a new item to the menu |
| Remove Menu Item | Remove an item from the menu |
| Update Menu Settings | Modify menu appearance settings |

**Return Values:**

Show menu intents return a `MenuSelectionResult` (see [Selection Result Format](#selection-result-format)).

### AppleScript / JXA

The app includes a scripting dictionary (`RadialMenu.sdef`) for AppleScript and JavaScript for Automation.

**Classes:**

- `application`: Properties for `menu visible`, `menu items`, `named menus`
- `menu item`: Properties for `id`, `title`, `icon name`, `action type`, `action value`, `position`
- `named menu`: Properties for `name`, `description`, `item count`
- `menu selection`: Properties for `was dismissed`, `selected item`

**Commands:**

| Command | Description |
|---------|-------------|
| `show menu` | Show menu, optionally with name or JSON |
| `hide menu` | Hide the menu |
| `toggle menu` | Toggle visibility |
| `execute item` | Execute by title or UUID |

**AppleScript Examples:**

```applescript
-- Show menu and get selection
tell application "Radial Menu"
    set result to show menu return only true
    if not (was dismissed of result) then
        return title of selected item of result
    end if
end tell

-- Show named menu
tell application "Radial Menu"
    show menu "development"
end tell

-- List all menu items
tell application "Radial Menu"
    repeat with item in menu items
        log (title of item)
    end repeat
end tell

-- Execute item by title
tell application "Radial Menu"
    execute item "Terminal"
end tell
```

**JXA Example:**

```javascript
const app = Application("Radial Menu");
const result = app.showMenu("development", { returnOnly: true });
if (!result.wasDismissed()) {
    console.log(result.selectedItem().title());
}
```

### Menu JSON Format

Custom menus can be defined with JSON. The `version` field is required.

```json
{
  "version": 1,
  "name": "My Menu",
  "items": [
    {
      "title": "Terminal",
      "iconName": "terminal",
      "action": { "launchApp": { "path": "/Applications/Utilities/Terminal.app" } }
    },
    {
      "title": "Run Script",
      "iconName": "script",
      "action": { "runShellCommand": { "command": "echo hello" } }
    },
    {
      "title": "Screenshot",
      "iconName": "camera",
      "action": { "simulateKeyboardShortcut": { "modifiers": ["command", "shift"], "key": "4" } }
    }
  ]
}
```

**Action Types:**

| Type | Format |
|------|--------|
| Launch App | `{ "launchApp": { "path": "/path/to/app" } }` |
| Shell Command | `{ "runShellCommand": { "command": "..." } }` |
| Keyboard Shortcut | `{ "simulateKeyboardShortcut": { "modifiers": [...], "key": "..." } }` |
| Activate App | `{ "activateApp": { "bundleID": "com.app.id" } }` |
| Internal Command | `{ "internalCommand": { "command": "switchApp" } }` |
| Task Switcher | `{ "openTaskSwitcher": {} }` |

### Selection Result Format

When the menu is invoked by an external process with `returnOnly` or `returnTo`, the result is returned as JSON. Schema: `schemas/menu-selection-result.schema.json`

**Selection made:**

```json
{
  "wasDismissed": false,
  "selectedItem": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Terminal",
    "iconName": "terminal",
    "actionType": "launchApp",
    "position": 0
  }
}
```

**Dismissed without selection:**

```json
{
  "wasDismissed": true,
  "selectedItem": null
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `wasDismissed` | boolean | True if menu closed without selection |
| `selectedItem` | object/null | Selected item details, or null if dismissed |
| `selectedItem.id` | string (UUID) | Unique item identifier |
| `selectedItem.title` | string | Display title |
| `selectedItem.iconName` | string | Icon name (SF Symbol or custom) |
| `selectedItem.actionType` | string | One of: `launchApp`, `runShellCommand`, `keyboardShortcut`, `taskSwitcher`, `activateApp`, `internalCommand` |
| `selectedItem.position` | integer | 0-based position in menu |

## Icon Assets

### Icon Set System

The app uses a flexible icon set system with:

- **Built-in icon sets**: Defined in `BuiltInIconSets.swift`, embedded in code (not loaded from bundle)
- **User icon sets**: Loaded from `~/Library/Application Support/com.radial-menu/icon-sets/`
- **Icon resolution**: `IconResolver` maps semantic icon names to actual icons via `IconSetDefinition`

### Built-in Icon Sets

Four built-in icon sets (defined in `Infrastructure/IconSets/BuiltInIconSets.swift`):

| Identifier | Name | Description |
|------------|------|-------------|
| `outline` | Outline | SF Symbols in outline style (default) |
| `filled` | Filled | SF Symbols in filled style |
| `simple` | Simple | Single-tone, high-contrast SF Symbols |
| `bootstrap` | Bootstrap | Bootstrap-style with full-color accents |

### Icon Resolution Flow

```
MenuItem.iconName (e.g., "terminal")
    ↓
IconSetProvider.resolveIcon()
    ↓
IconResolver.resolve() - Pure function
    ↓
Checks IconSetDefinition.icons map
    ↓
If found: Return IconDefinition (file, systemSymbol, or assetName)
If not found: Apply FallbackConfig.strategy
    ↓
ResolvedIcon (ready for rendering)
```

### User-Defined Icon Sets

Users can import custom icon sets via Preferences. Each icon set requires:

```
my-icon-set/
├── manifest.json
└── icons/
    ├── terminal.pdf
    └── ...
```

**manifest.json structure:**
```json
{
  "version": 1,
  "identifier": "my-icon-set",
  "name": "My Icon Set",
  "description": "Optional description",
  "author": { "name": "Author", "url": "https://..." },
  "icons": {
    "terminal": "terminal.pdf",
    "safari": { "file": "safari.pdf", "preserveColors": true },
    "camera": { "systemSymbol": "camera.fill" }
  },
  "fallback": { "strategy": "system" }
}
```

Icon definition formats:
- Shorthand: `"terminal": "terminal.pdf"` (assumes file in `icons/` directory)
- Full object: `{ "file": "...", "systemSymbol": "...", "preserveColors": true }`

### Asset Location

Built-in asset catalog images live in `radial-menu/radial-menu/Assets.xcassets/`.

### Adding Custom Icons

1. Create icon (SVG recommended)
2. Convert to PDF: `rsvg-convert -f pdf -o icon.pdf icon.svg`
3. Add to icon set's `icons/` directory
4. Reference in `manifest.json`

All icons are rendered with monochrome tinting unless `preserveColors: true` is set.

## Testing Strategy

### Pure Function Tests

Domain layer geometry functions are tested with straightforward unit tests (no mocking needed):

```swift
// Example: RadialGeometryTests.swift
func testCalculateSlices_WithFourItems_CreatesCorrectAngles() {
    let slices = RadialGeometry.calculateSlices(
        itemCount: 4,
        radius: 100.0,
        centerPoint: CGPoint(x: 200, y: 200)
    )
    XCTAssertEqual(slices.count, 4)
}
```

### Mock-Based Tests

Infrastructure components are protocol-based, enabling mock injection:

```swift
let mockExecutor = MockActionExecutor()
let viewModel = RadialMenuViewModel(
    configManager: mockConfigManager,
    actionExecutor: mockExecutor,
    overlayWindow: mockWindow
)
```

Mock implementations live in `radial-menuTests/Mocks/`.

## Common Development Tasks

### Adding a New Menu Action Type

1. Add case to `ActionType` enum (Domain/Models/ActionType.swift)
2. Update `ActionExecutor.execute(_:)` (Infrastructure/Actions/ActionExecutor.swift)
3. Update `PreferencesView` to expose new action type
4. Add tests for new action execution

### Modifying Geometry Calculations

1. Update pure functions in `Domain/Geometry/`
2. Add/update unit tests in `radial-menuTests/Domain/`
3. No mocking required - these are pure functions

### Adding New Input Method

1. Define protocol in `Infrastructure/Input/`
2. Implement concrete class
3. Wire in `AppCoordinator.init()` and `AppCoordinator.start()`
4. Add callback to `RadialMenuViewModel`

### Creating a New Built-in Icon Set

1. Add new static property to `BuiltInIconSets` enum (`Infrastructure/IconSets/BuiltInIconSets.swift`)
2. Create `IconSetDescriptor` with unique identifier
3. Define icon mappings in `icons` dictionary
4. Add to `BuiltInIconSets.all` array
5. Test icon resolution via Preferences

### Adding Accessibility Support to New Features

1. Add appropriate `accessibilityLabel`, `accessibilityHint`, and traits to SwiftUI views
2. Use `AccessibilityManager.announce()` for important state changes
3. Respect `@Environment(\.accessibilityReduceMotion)` for animations
4. Test with VoiceOver enabled

### Adding a New App Intent

1. Create intent struct in `Infrastructure/Shortcuts/Intents/`
2. Implement `AppIntent` protocol with `title`, `description`, `perform()`
3. Add parameters with `@Parameter` property wrapper
4. Return appropriate result type (use `MenuSelectionResultEntity` for menu operations)
5. Add shortcut phrase in `RadialMenuShortcuts.swift`
6. Use `ShortcutsServiceLocator.shared.externalRequestHandler` for menu operations

### Adding a New AppleScript Command

1. Define command in `RadialMenu.sdef` with code, parameters, and result type
2. Create `NSScriptCommand` subclass in `Infrastructure/Scripting/`
3. Override `performDefaultImplementation()` to handle the command
4. Use `ShortcutsServiceLocator.shared.externalRequestHandler` for menu operations
5. Set `scriptErrorNumber` and `scriptErrorString` on errors

## Accessibility

The app provides comprehensive accessibility support:

### VoiceOver

- **Menu announcements**: "Radial menu opened with N items"
- **Item announcements**: Label and position ("Terminal, 1 of 8")
- **Action feedback**: "Activated Terminal"
- **Navigation hints**: "Use arrow keys to navigate, Return to select"

### Implementation

- `AccessibilityManager` (`Infrastructure/Accessibility/`): Handles announcements via `NSAccessibility.post()`
- `AccessibleSliceElement`: Custom accessibility element for slices
- `@AccessibilityFocusState` in `RadialMenuView`: Syncs VoiceOver focus with selection
- `MenuItem.accessibilityLabel/Hint`: Optional per-item overrides

### Reduce Motion

The app respects `@Environment(\.accessibilityReduceMotion)`:
- When enabled, slice animations are disabled
- Selection changes are instant rather than animated

## Code Signing

Code signing is **disabled** for Debug and Release configurations to simplify local CLI builds. This is configured in the Xcode project settings.

## Accessibility Permissions

The app requires Accessibility permissions to register global hotkeys. If hotkey registration fails:

1. Open System Settings
2. Navigate to Privacy & Security → Accessibility
3. Add radial-menu.app to the allowed list
4. Restart the app

The `scripts/test-hotkey.sh` script provides detailed feedback if permissions are missing.
