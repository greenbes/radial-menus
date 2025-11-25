# Radial Menu Overlay

Lightweight macOS radial menu with configurable actions, icon sets, and keyboard/controller navigation.

## Features

- Radial menu overlay with configurable items (add/remove via Preferences)
- Actions: launch apps, run shell commands, simulate keyboard shortcuts
- Appearance: selectable icon sets (Outline, Filled, Simple, Bootstrap), customizable colors (background, foreground, selected item), adjustable radius and center radius
- Position: configurable launch location (at cursor or screen center), drag to reposition
- Menu bar only app (no Dock icon) with Preferences window for full configuration
- Visual feedback: menu dims when losing keyboard focus
- User-defined icon sets: import custom icon sets with PDF/SVG icons
- Full accessibility support: VoiceOver announcements, keyboard navigation, reduce motion
- Shortcuts integration: App Intents for Siri, Shortcuts app, and Spotlight
- URL scheme for scripting: `radial-menu://` protocol for shell/AppleScript automation

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
- Drag from center circle to reposition menu

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

# Generate build info (includes git commit hash and timestamp)
./scripts/generate-build-info.sh

# Build Debug
xcodebuild -project radial-menu/radial-menu.xcodeproj -scheme radial-menu -configuration Debug build

# Launch with logging
./scripts/run-with-logs.sh

# Hotkey test helper
./scripts/test-hotkey.sh
```

Each build includes a unique build ID (git commit hash + dirty flag), visible in the About dialog.

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
- `LogShortcuts()` - App Intents, URL scheme

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

## Shortcuts & Automation

### App Intents (Shortcuts App)

The app integrates with macOS Shortcuts via App Intents. Available actions:

| Action | Description |
|--------|-------------|
| Execute Menu Item | Run any configured menu item's action |
| Toggle Radial Menu | Show, hide, or toggle menu visibility |
| Get Menu Items | List all configured menu items |
| Add Menu Item | Create a new menu item |
| Remove Menu Item | Delete a menu item |
| Update Menu Settings | Change radius, icon set, position mode |

Siri phrases:
- "Run Terminal in Radial Menu"
- "Toggle Radial Menu"
- "List Radial Menu items"

### URL Scheme

Control the app from shell scripts, AppleScript, or other automation tools:

```bash
# Show/hide/toggle menu
open "radial-menu://show"
open "radial-menu://hide"
open "radial-menu://toggle"

# Show a named menu (stored in ~/Library/Application Support/com.radial-menu/menus/)
open "radial-menu://show?menu=development"

# Show menu from a file path (ephemeral, one-time use)
open "radial-menu://show?file=/path/to/menu.json"

# Show menu from inline JSON (ephemeral, URL-encoded)
open "radial-menu://show?json=%7B%22version%22%3A1%2C%22name%22%3A%22temp%22%2C%22items%22%3A%5B...%5D%7D"

# Execute menu item by title
open "radial-menu://execute?title=Terminal"

# Execute menu item by UUID
open "radial-menu://execute?item=<uuid>"
```

AppleScript example:
```applescript
do shell script "open 'radial-menu://execute?title=Screenshot'"
```

### Named Menus

Store custom menus as JSON files in:
```
~/Library/Application Support/com.radial-menu/menus/<name>.json
```

**Named menu JSON format:**
```json
{
  "version": 1,
  "name": "development",
  "description": "Development tools and apps",
  "items": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "VS Code",
      "iconName": "chevron.left.forwardslash.chevron.right",
      "action": {
        "launchApp": {
          "path": "/Applications/Visual Studio Code.app"
        }
      }
    }
  ],
  "appearanceSettings": {
    "radius": 180.0,
    "iconSetIdentifier": "filled"
  }
}
```

- `version`: Schema version (required, use 1)
- `name`: Menu identifier for invocation (required)
- `description`: Human-readable description (optional)
- `items`: Array of MenuItem (required, non-empty)
- `appearanceSettings`: Overrides (optional, uses defaults if omitted)
- `behaviorSettings`: Overrides (optional, uses defaults if omitted)
