# Radial Menu Overlay

Lightweight macOS radial menu with configurable actions, icon sets, and keyboard/controller navigation.

## Features

- Radial menu overlay with configurable items (add/remove via Preferences)
- Actions: launch apps, run shell commands, simulate keyboard shortcuts
- Appearance: selectable icon sets (Outline, Filled, Simple, Bootstrap), customizable colors (background, foreground, selected item), adjustable radius and center radius
- Position: configurable launch location (at cursor or screen center)
- Menu bar item with Preferences window for full configuration

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

- Assets live in `radial-menu/Assets.xcassets`. Bootstrap icons use the converted PDFs under `bootstrap_*.imageset/`.
- Icon set is selectable in Preferences. All icons are rendered in a single tint to avoid inconsistent palette issues.
- Use `rsvg-convert` to convert SVG to PDF.

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

- Use `Log("message")` for debug output (defined in `Logger.swift`)
- Logs are written to `/tmp/radial-menu-debug.log`
- When running with `./scripts/run-with-logs.sh`, logs are automatically tailed
- Do NOT use `print()` statements - they won't appear in the log file
