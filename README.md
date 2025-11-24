# Radial Menu Overlay

Lightweight macOS radial menu with configurable actions, icon sets, and keyboard/controller navigation.

## Features
- Radial menu overlay with configurable items (add/remove via Preferences).
- Actions: launch apps, run shell commands, simulate keyboard shortcuts.
- Input: mouse/trackpad, keyboard navigation (arrow keys), optional controller navigation.
- Appearance: selectable icon sets (Outline, Filled, Simple, Bootstrap), customizable colors (background, foreground, selected item), adjustable radius and center radius.
- Position: configurable launch location (at cursor or screen center).
- Menu bar item with Preferences window for full configuration.

## Icon Sets
- Assets live in `radial-menu/Assets.xcassets`. Bootstrap icons use the converted PDFs under `bootstrap_*.imageset/`.
- Icon set is selectable in Preferences. All icons are rendered in a single tint to avoid inconsistent palette issues.
- Use `rsvg-convert` to convert SVG to PDF.

## Build & Run (CLI only)
- Resolve dependencies (if needed): `xcodebuild -resolvePackageDependencies -scheme radial-menu`.
- Build Debug: `xcodebuild -project radial-menu/radial-menu.xcodeproj -scheme radial-menu -configuration Debug build`.
  - Code signing is disabled for local Debug/Release in the project settings.
  - Uses system DerivedData location (typically `~/Library/Developer/Xcode/DerivedData`).
- Launch with logging: `./run-with-logs.sh` (finds the latest Debug build and tails `/tmp/radial-menu-debug.log`).
- Hotkey test helper: `./test-hotkey.sh`.

## Development Notes
- Files follow Clean Architecture:
  - `Domain/` pure models/geometry
  - `Infrastructure/` system managers (overlay, hotkey, controller input)
  - `Presentation/` SwiftUI views + view models (MVVM)
- Default configuration is in `MenuConfiguration.sample()`. User config persists at `~/Library/Application Support/com.radial-menu/radial-menu-config.json` (not checked in).
- Preview macros and SwiftData templates were removed to keep CLI builds stable.

## Debugging
- Use `Log("message")` for debug output (defined in `Logger.swift`).
- Logs are written to `/tmp/radial-menu-debug.log`.
- When running with `./run-with-logs.sh`, logs are automatically tailed.
- Do NOT use `print()` statements - they won't appear in the log file.
