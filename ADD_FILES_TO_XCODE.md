# How to Add Missing Files to Xcode Project

The Swift files have been created in the filesystem, but Xcode doesn't know about them yet. You need to add them to the Xcode project target.

## Quick Fix (Recommended)

1. **Open Xcode**:
   ```bash
   open radial-menu.xcodeproj
   ```

2. **Add All Missing Files**:
   - In Xcode, right-click on the `radial-menu` folder in the Project Navigator (left sidebar)
   - Select **"Add Files to 'radial-menu'..."**
   - Navigate to your project directory
   - Select **ALL** these folders:
     - `Domain` (and all subfolders)
     - `Infrastructure` (and all subfolders)
     - `Presentation` (and all subfolders)
   - Make sure these options are checked:
     - ✅ "Copy items if needed" (UNCHECKED - files are already there)
     - ✅ "Create groups"
     - ✅ "Add to targets: radial-menu"
   - Click **"Add"**

3. **Add Individual Files** (if you prefer):
   - Right-click on `radial-menu` folder → "Add Files to 'radial-menu'..."
   - Add these files one by one:
     - `AppCoordinator.swift`
     - All files in `Domain/Models/`
     - All files in `Domain/Geometry/`
     - All files in `Infrastructure/Input/`
     - All files in `Infrastructure/Window/`
     - All files in `Infrastructure/Actions/`
     - All files in `Infrastructure/Configuration/`
     - All files in `Presentation/RadialMenu/`
     - All files in `Presentation/Preferences/`
     - All files in `Presentation/MenuBar/`

## Files That Need to Be Added

Here's the complete list of files to add:

### Root Level
- `AppCoordinator.swift`

### Domain/Models/
- `ActionType.swift`
- `MenuItem.swift`
- `MenuConfiguration.swift`
- `MenuState.swift`

### Domain/Geometry/
- `RadialGeometry.swift`
- `HitDetector.swift`
- `SelectionCalculator.swift`

### Infrastructure/Input/
- `HotkeyManagerProtocol.swift`
- `HotkeyManager.swift`
- `ControllerInputProtocol.swift`
- `ControllerInputManager.swift`
- `EventMonitorProtocol.swift`

### Infrastructure/Window/
- `OverlayWindowProtocol.swift`
- `OverlayWindowController.swift`
- `RadialMenuContainerView.swift`

### Infrastructure/Actions/
- `ActionExecutorProtocol.swift`
- `ActionExecutor.swift`

### Infrastructure/Configuration/
- `ConfigurationManagerProtocol.swift`
- `ConfigurationManager.swift`

### Presentation/RadialMenu/
- `RadialMenuView.swift`
- `SliceView.swift`
- `RadialMenuViewModel.swift`

### Presentation/Preferences/
- `PreferencesView.swift`

### Presentation/MenuBar/
- `MenuBarController.swift`

## After Adding Files

1. **Clean Build Folder**:
   - In Xcode menu: `Product → Clean Build Folder` (Shift+Cmd+K)

2. **Rebuild**:
   - In Xcode menu: `Product → Build` (Cmd+B)

3. **Run**:
   - Click the Play button or press Cmd+R

## Files to DELETE (No Longer Needed)

These are from the original template and should be removed:
- `Item.swift` (old template file)
- `ContentView.swift` (old template file)

To delete in Xcode:
1. Select the file in Project Navigator
2. Press Delete
3. Choose "Move to Trash"

## Verify Everything Was Added

After adding files, check the Project Navigator. Your structure should look like:

```
radial-menu/
├── App/
│   ├── radial_menuApp.swift
│   ├── AppDelegate.swift
│   └── AppCoordinator.swift
├── Domain/
│   ├── Models/
│   └── Geometry/
├── Infrastructure/
│   ├── Input/
│   ├── Window/
│   ├── Actions/
│   └── Configuration/
└── Presentation/
    ├── RadialMenu/
    ├── Preferences/
    └── MenuBar/
```

All files should have a checkbox next to them in the "Target Membership" section of the File Inspector (right sidebar).
