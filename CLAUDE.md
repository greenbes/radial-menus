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
# Launch with logging (finds latest Debug build, tails /tmp/radial-menu-debug.log)
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
~/Library/Application Support/com.radial-menu/radial-menu-config.json
```

### User Icon Sets

User-imported icon sets are stored at:
```
~/Library/Application Support/com.radial-menu/icon-sets/<identifier>/
```

Each icon set directory contains a `manifest.json` and an `icons/` subdirectory.

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
- `LogError()` - Errors (specify category)

**Viewing logs:**
```bash
# Stream all logs
log stream --predicate 'subsystem == "Six-Gables-Software.radial-menu"' --level debug

# Filter by category
log stream --predicate 'subsystem == "Six-Gables-Software.radial-menu" AND category == "Input"'

# Or use the helper script
./scripts/run-with-logs.sh
```

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
  - A button → Confirm
  - Menu button → Toggle menu
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
