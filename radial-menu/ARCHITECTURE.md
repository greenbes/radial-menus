# Radial Menu Architecture

## Overview

The Radial Menu application follows **Clean Architecture** principles with a focus on testability, separation of concerns, and the **Functional Core / Imperative Shell** pattern.

## Architecture Layers

### 1. Domain Layer (Pure Business Logic)

Location: `Domain/`

Pure Swift code with no dependencies on frameworks. Fully testable with unit tests.

#### Models

- `MenuItem`: Represents a menu item with title, icon, and action
- `MenuConfiguration`: Complete menu configuration including appearance and behavior settings
- `ActionType`: Enum defining types of actions (launch app, run command, keyboard shortcut)
- `MenuState`: State machine for menu lifecycle

#### Geometry (Pure Functions)

- `RadialGeometry`: Calculate slice positions, angles, and transformations
- `HitDetector`: Determine if a point is inside the menu or a specific slice
- `SelectionCalculator`: Calculate selected slice from various inputs (mouse, controller, keyboard)

**Why pure functions?** These are side-effect-free, deterministic functions that are trivial to test and reason about.

### 2. Infrastructure Layer (System Integration)

Location: `Infrastructure/`

Protocol-based implementations for system interactions. All protocols enable easy mocking in tests.

#### Input Management

- `HotkeyManagerProtocol` → `HotkeyManager`: Global hotkey registration using Carbon Event Manager
- `ControllerInputProtocol` → `ControllerInputManager`: Game controller support via GameController framework
- `EventMonitorProtocol`: Mouse and keyboard event monitoring

#### Window Management

- `OverlayWindowProtocol` → `OverlayWindowController`: Transparent, floating NSPanel
- `RadialMenuContainerView`: Custom NSView with dynamic click-through behavior

#### Action Execution

- `ActionExecutorProtocol` → `ActionExecutor`: Execute menu actions
  - Launch applications via NSWorkspace
  - Run shell commands via Process
  - Simulate keyboard shortcuts via CGEvent

#### Configuration

- `ConfigurationManagerProtocol` → `ConfigurationManager`: JSON-based persistence to Application Support directory

### 3. Presentation Layer (UI + ViewModels)

Location: `Presentation/`

SwiftUI views and observable ViewModels following MVVM pattern.

#### Views

- `RadialMenuView`: Main radial menu with slices arranged in circle
- `SliceView`: Individual menu item slice with icon and label
- `PreferencesView`: Configuration interface

#### ViewModels

- `RadialMenuViewModel`: Manages menu state, coordinates input → action flow
  - Uses `@Observable` for reactive state updates
  - Orchestrates geometry calculations, input handling, and action execution
  - Single source of truth for menu state

#### Controllers

- `MenuBarController`: Manages NSStatusItem and preferences window

### 4. Application Layer (Coordination)

Location: Root

- `AppCoordinator`: Composition root that wires all dependencies
  - Creates infrastructure components
  - Creates ViewModels with dependency injection
  - Sets up input handlers and callbacks
  - Manages application lifecycle

- `AppDelegate`: Minimal delegate that creates and starts the coordinator

## Data Flow

```
User Input (Hotkey/Controller/Mouse)
    ↓
Input Manager (Infrastructure)
    ↓
ViewModel (Presentation)
    ↓
Geometry Calculator (Domain - Pure Functions)
    ↓
ViewModel Updates State
    ↓
View Renders (SwiftUI)

User Confirms Selection
    ↓
ViewModel
    ↓
ActionExecutor (Infrastructure)
    ↓
System (Launch App, Run Command, etc.)
```

## Dependency Injection

All dependencies flow inward:
- Domain layer has ZERO dependencies
- Infrastructure implements protocols
- Presentation depends on protocols (not concrete implementations)
- AppCoordinator creates and injects everything

Example:
```swift
class RadialMenuViewModel {
    init(
        configManager: ConfigurationManagerProtocol,  // Protocol, not concrete class
        actionExecutor: ActionExecutorProtocol,       // Protocol, not concrete class
        overlayWindow: OverlayWindowProtocol          // Protocol, not concrete class
    )
}
```

## Testability

### Pure Function Tests
```swift
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
```swift
let mockExecutor = MockActionExecutor()
let viewModel = RadialMenuViewModel(
    configManager: mockConfigManager,
    actionExecutor: mockExecutor,  // Inject mock
    overlayWindow: mockWindow
)

viewModel.handleConfirm()
XCTAssertEqual(mockExecutor.executeCallCount, 1)
```

## File Organization

```
radial-menu/
├── App/
│   ├── RadialMenuApp.swift
│   ├── AppDelegate.swift
│   └── AppCoordinator.swift
├── Domain/
│   ├── Models/
│   │   ├── MenuItem.swift
│   │   ├── MenuConfiguration.swift
│   │   ├── ActionType.swift
│   │   └── MenuState.swift
│   └── Geometry/
│       ├── RadialGeometry.swift
│       ├── HitDetector.swift
│       └── SelectionCalculator.swift
├── Infrastructure/
│   ├── Input/
│   │   ├── HotkeyManagerProtocol.swift
│   │   ├── HotkeyManager.swift
│   │   ├── ControllerInputProtocol.swift
│   │   ├── ControllerInputManager.swift
│   │   └── EventMonitorProtocol.swift
│   ├── Window/
│   │   ├── OverlayWindowProtocol.swift
│   │   ├── OverlayWindowController.swift
│   │   └── RadialMenuContainerView.swift
│   ├── Actions/
│   │   ├── ActionExecutorProtocol.swift
│   │   └── ActionExecutor.swift
│   └── Configuration/
│       ├── ConfigurationManagerProtocol.swift
│       └── ConfigurationManager.swift
└── Presentation/
    ├── RadialMenu/
    │   ├── RadialMenuView.swift
    │   ├── SliceView.swift
    │   └── RadialMenuViewModel.swift
    ├── Preferences/
    │   └── PreferencesView.swift
    └── MenuBar/
        └── MenuBarController.swift
```

## Key Design Patterns

1. **Clean Architecture**: Clear layer boundaries, dependency inversion
2. **Functional Core / Imperative Shell**: Pure logic in Domain, side effects in Infrastructure
3. **MVVM**: Views bind to ViewModels, ViewModels orchestrate business logic
4. **Protocol-Oriented Design**: All infrastructure behind protocols for testability
5. **Dependency Injection**: Constructor injection, composition root in AppCoordinator
6. **State Machine**: Clear state transitions (Closed → Opening → Open → Executing → Closing)

## Configuration Storage

Configuration is stored as JSON in:
```
~/Library/Application Support/com.radial-menu/radial-menu-config.json
```

Following macOS conventions (equivalent to XDG_CONFIG_HOME on other platforms).

## Input Handling

### Global Hotkey
- Default: `Ctrl + Space`
- Implemented via Carbon Event Manager
- Requires Accessibility permissions

### Controller
- Supports Xbox, PlayStation, and MFi controllers
- Left stick for selection
- A button for confirmation
- Menu button to toggle menu
- 60Hz polling for responsive input

### Mouse
- Move to select slice
- Click to confirm
- Click outside to dismiss (with click-through to underlying apps)

### Keyboard
- Right Arrow: Select next slice clockwise
- Left Arrow: Select next slice counter-clockwise
- Escape: Close menu without action

## Next Steps

1. **Add more tests**: Cover ViewModels, integration tests
2. **Enhanced preferences**: Full CRUD for menu items
3. **Themes**: Support for custom color schemes
4. **Multiple menus**: Support profiles/contexts
5. **Animations**: Smooth transitions and effects
6. **Accessibility**: VoiceOver support, high-contrast mode
