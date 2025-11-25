# Radial Menu Overlay

Lightweight macOS radial menu with configurable actions, icon sets, and keyboard/controller navigation.

## Features

- Radial menu overlay with configurable items (add/remove via Preferences)
- Actions: launch apps, run shell commands, simulate keyboard shortcuts
- Appearance: selectable icon sets (Outline, Filled, Simple, Bootstrap), customizable colors (background, foreground, selected item), adjustable radius and center radius
- Position: configurable launch location (at cursor or screen center)
- Menu bar item with Preferences window for full configuration
- User-defined icon sets: import custom icon sets with PDF/SVG icons
- Full accessibility support: VoiceOver announcements, keyboard navigation, reduce motion

## Input Methods

### Keyboard

- **Ctrl + Space**: Toggle menu open/close
- **Left/Right Arrow**: Navigate slices counter-clockwise/clockwise
- **Enter**: Activate selected item
- **Escape**: Close menu without action

### Mouse

- Move cursor to select slice
- Click to activate selected item
- Click outside menu to close

### Game Controller

Full game controller support with background monitoring (works even when another app has focus).

| Button | Action |
|--------|--------|
| Home | Toggle menu open/close |
| D-pad Left/Right | Navigate slices counter-clockwise/clockwise |
| A (Xbox) / X (PlayStation) | Activate selected item |
| B (Xbox) / Circle (PlayStation) | Close menu without action |
| Left Stick | Select slice by direction |
| Right Stick | Reposition menu on screen |

Controller settings:

- Joystick deadzone is configurable in Preferences (10-50%, default 30%)
- Movement speed scales with stick deflection (further = faster)

## Icon Sets

### Built-in Icon Sets

Four built-in icon sets (selectable in Preferences):

| Icon Set | Description |
|----------|-------------|
| Outline | SF Symbols in outline style (default) |
| Filled | SF Symbols in filled style |
| Simple | Single-tone, high-contrast SF Symbols |
| Bootstrap | Bootstrap-style icons with special full-color accents |

All icons are rendered with monochrome tinting unless `preserveColors` is set.

### User-Defined Icon Sets

Import custom icon sets via Preferences → Icon Sets → Import. User icon sets are stored at:
```
~/Library/Application Support/com.radial-menu/icon-sets/<identifier>/
```

Each icon set requires a `manifest.json` and an `icons/` directory:

```
my-icon-set/
├── manifest.json
└── icons/
    ├── terminal.pdf
    ├── safari.pdf
    └── ...
```

**manifest.json format:**
```json
{
  "version": 1,
  "identifier": "my-icon-set",
  "name": "My Icon Set",
  "description": "Custom icons for my workflow",
  "author": {
    "name": "Your Name",
    "url": "https://example.com"
  },
  "icons": {
    "terminal": "terminal.pdf",
    "safari": { "file": "safari.pdf" },
    "camera": { "systemSymbol": "camera.fill" },
    "special": { "file": "special.pdf", "preserveColors": true }
  },
  "fallback": {
    "strategy": "system"
  }
}
```

- Icons can be PDF files (converted from SVG) or SF Symbol references
- Use `rsvg-convert -f pdf -o icon.pdf icon.svg` to convert SVG to PDF
- `preserveColors: true` renders the icon in its original colors instead of tinting

### Asset Location

Built-in assets live in `radial-menu/Assets.xcassets/`.

## Accessibility

Full VoiceOver support:

- Menu items announce their label and position ("Terminal, 1 of 8")
- State changes announced ("Radial menu opened with 8 items")
- Custom accessibility labels and hints can be set per menu item
- Respects system "Reduce Motion" preference
- Keyboard navigation works with VoiceOver focus tracking

## Build & Run (CLI only)

```bash
# Resolve dependencies (if needed)
xcodebuild -resolvePackageDependencies -scheme radial-menu

# Build Debug
xcodebuild -project radial-menu/radial-menu.xcodeproj -scheme radial-menu -configuration Debug build

# Launch with logging
./scripts/run-with-logs.sh

# Hotkey test helper
./scripts/test-hotkey.sh
```

Code signing is disabled for local Debug/Release in the project settings.

## Development Notes

Files follow Clean Architecture:

- `Domain/` - pure models/geometry
- `Infrastructure/` - system managers (overlay, hotkey, controller input)
- `Presentation/` - SwiftUI views + view models (MVVM)

Default configuration is in `MenuConfiguration.sample()`. User config persists at `~/Library/Application Support/com.radial-menu/radial-menu-config.json`.

## Debugging

The app uses Apple's Unified Logging System (os_log). Use category-specific log functions:

- `LogLifecycle()` - App startup, shutdown
- `LogInput()` - Hotkey, keyboard, mouse, controller
- `LogMenu()` - Menu state, selection
- `LogWindow()` - Window management
- `LogGeometry()` - Hit detection calculations
- `LogAction()` - Action execution
- `LogConfig()` - Configuration
- `LogError()` - Errors (specify category)

View logs:
```bash
# Stream all logs
log stream --predicate 'subsystem == "Six-Gables-Software.radial-menu"' --level debug

# Filter by category
log stream --predicate 'subsystem == "Six-Gables-Software.radial-menu" AND category == "Input"'

# Or use the helper script
./scripts/run-with-logs.sh
```

Do NOT use `print()` statements.
