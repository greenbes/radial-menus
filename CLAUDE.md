# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Radial Menu is a macOS menu bar application that displays a configurable radial overlay menu triggered by hotkey, controller, mouse, or keyboard. The app follows Clean Architecture with Functional Core / Imperative Shell pattern and SOLID principles.

## Build & Run Commands

### Building

```bash
# Resolve dependencies (if needed)
xcodebuild -resolvePackageDependencies -scheme radial-menu -project radial-menu/radial-menu.xcodeproj

# Build Debug (uses system DerivedData location)
xcodebuild -project radial-menu/radial-menu.xcodeproj -scheme radial-menu -configuration Debug build

# Build Release
xcodebuild -project radial-menu/radial-menu.xcodeproj -scheme radial-menu -configuration Release build

# Note: If you encounter "Multiple commands produce" errors, remove any local DerivedData:
# rm -rf radial-menu/radial-menu/DerivedData
```

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
  Models/        - MenuItem, MenuConfiguration, ActionType, MenuState, IconSet
  Geometry/      - Pure functions: RadialGeometry, HitDetector, SelectionCalculator

Infrastructure/  - System integration via protocols
  Input/         - HotkeyManager, ControllerInputManager, EventMonitor
  Window/        - OverlayWindowController, RadialMenuContainerView
  Actions/       - ActionExecutor (launch apps, run commands, keyboard shortcuts)
  Configuration/ - ConfigurationManager (JSON persistence)

Presentation/    - SwiftUI views + ViewModels (MVVM)
  RadialMenu/    - RadialMenuView, SliceView, RadialMenuViewModel
  Preferences/   - PreferencesView
  MenuBar/       - MenuBarController

Root/            - App coordination
  AppCoordinator - Composition root, dependency injection
  AppDelegate    - Minimal delegate
```

### Key Architectural Patterns

1. **Protocol-Oriented Design**: All infrastructure components implement protocols (e.g., `ConfigurationManagerProtocol`, `ActionExecutorProtocol`) for testability and dependency injection
2. **Dependency Injection**: Constructor injection throughout, all dependencies wired in `AppCoordinator`
3. **Pure Functions in Domain**: Geometry calculations are side-effect-free, deterministic functions
4. **State Machine**: Menu lifecycle follows clear state transitions (Closed → Opening → Open → Executing → Closing)
5. **MVVM in Presentation**: Views bind to `@Observable` ViewModels

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
ViewModel Updates State (@Observable)
    ↓
View Renders (SwiftUI)
    ↓
User Confirms Selection
    ↓
ActionExecutor (Infrastructure) - Launch app, run command, keyboard shortcut
```

## Configuration & Storage

### User Configuration

Configuration persists as JSON at:
```
~/Library/Application Support/com.radial-menu/radial-menu-config.json
```

### Default Configuration

Default menu items and settings are defined in `MenuConfiguration.sample()` (Domain/Models/MenuConfiguration.swift:64-112):
- 8 sample items: Terminal, Safari, Screenshot, Mute, Calendar, Notes, Reminders, Files
- Icon set: Outline (configurable via Preferences)
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

### Icon Sets

Four icon sets available (selectable in Preferences):
- Outline (SF Symbols)
- Filled (SF Symbols)
- Simple (SF Symbols)
- Bootstrap (converted SVG → PDF)

### Asset Location

All icons live in `radial-menu/radial-menu/Assets.xcassets/`.

Bootstrap icons use converted PDFs under `bootstrap_*.imageset/` directories.

### Adding Bootstrap Icons

1. Download SVG from bootstrap-icons repository
2. Convert to PDF: `rsvg-convert -f pdf -o icon.pdf icon.svg`
3. Add to `Assets.xcassets` with appropriate imageset structure

All icons are rendered with monochrome tinting to ensure visual consistency.

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

## Code Signing

Code signing is **disabled** for Debug and Release configurations to simplify local CLI builds. This is configured in the Xcode project settings.

## Accessibility Permissions

The app requires Accessibility permissions to register global hotkeys. If hotkey registration fails:

1. Open System Settings
2. Navigate to Privacy & Security → Accessibility
3. Add radial-menu.app to the allowed list
4. Restart the app

The `scripts/test-hotkey.sh` script provides detailed feedback if permissions are missing.
