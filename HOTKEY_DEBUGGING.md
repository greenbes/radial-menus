# Hotkey Debugging Guide

## Quick Test

Run the test script to see detailed logs:

```bash
./test-hotkey.sh
```

Then press **Ctrl+Space** and watch the log output.

## What the Logs Tell You

### Scenario 1: Everything Works ✅

When you press Ctrl+Space, you should see:

```
🔥 HotkeyManager: HOTKEY EVENT RECEIVED!
🔥 HotkeyManager: Calling hotkey callback...
🎯 RadialMenuViewModel: toggleMenu() called, current state: closed
🎯 RadialMenuViewModel: Menu is closed, opening...
🎯 RadialMenuViewModel: Opening menu...
🎯 RadialMenuViewModel: Calculated 4 slices
🎯 RadialMenuViewModel: Showing overlay window...
🔥 HotkeyManager: Callback completed
🎯 RadialMenuViewModel: Transition to open state complete
```

**This means:** Hotkey is working, menu should appear!

### Scenario 2: Hotkey Not Registered ❌

At startup, you see:

```
❌ HotkeyManager: Failed to register hotkey, status=<some number>
❌ HotkeyManager: This likely means Accessibility permissions are not granted
⚠️  Warning: Failed to register global hotkey
```

**This means:** macOS is blocking the hotkey registration.

**Fix:**
1. Open **System Settings**
2. Go to **Privacy & Security → Accessibility**
3. Click the **🔒** to unlock
4. Click the **+** button
5. Navigate to and add `radial-menu.app`
6. Restart the app

### Scenario 3: Hotkey Registered But Not Firing ⚠️

At startup, you see:

```
✅ HotkeyManager: Hotkey registered successfully!
💡 HotkeyManager: Press Ctrl+Space to trigger the menu
```

But when you press Ctrl+Space, **nothing happens** (no logs).

**This means:** Either:
- Another app is capturing Ctrl+Space first
- macOS input monitoring permissions issue

**Fix:**
1. Check **System Settings → Privacy & Security → Input Monitoring**
2. Make sure `radial-menu` is in the list and enabled
3. Try a different hotkey (edit AppCoordinator.swift)
4. Check if another app uses Ctrl+Space (e.g., Spotlight alternatives)

### Scenario 4: Hotkey Fires But Menu Doesn't Appear ⚠️

You see:

```
🔥 HotkeyManager: HOTKEY EVENT RECEIVED!
🎯 RadialMenuViewModel: toggleMenu() called
🎯 RadialMenuViewModel: Opening menu...
```

But no menu appears on screen.

**This means:** Window creation or rendering issue.

**Check:**
- Look for additional error messages in the log
- The window might be behind other windows
- Try clicking on the desktop first, then press Ctrl+Space

## Full Startup Log (Expected)

When the app starts successfully, you should see:

```
🚀 AppDelegate: Application did finish launching
🚀 AppDelegate: Coordinator created
📋 AppCoordinator: Starting...
📋 AppCoordinator: Setting up menu bar...
📋 AppCoordinator: Menu bar setup complete
📋 AppCoordinator: Registering global hotkey...
🔑 HotkeyManager: Attempting to register hotkey with key=49, modifiers=...
✅ HotkeyManager: Event handler installed successfully
✅ HotkeyManager: Hotkey registered successfully!
💡 HotkeyManager: Press Ctrl+Space to trigger the menu
✅ Global hotkey registered successfully
📋 AppCoordinator: Starting controller monitoring...
📋 AppCoordinator: Controller monitoring started
📋 AppCoordinator: Updating overlay window content...
📋 AppCoordinator: Start complete!
🚀 AppDelegate: Coordinator started
```

## Common Issues

### "Command not found" when running ./test-hotkey.sh

Make it executable:
```bash
chmod +x test-hotkey.sh
```

### No logs appear at all

The app might have crashed immediately. Check:
```bash
ls -la ~/Library/Logs/DiagnosticReports/radial-menu*
```

### Logs show but hotkey still doesn't work

Share the full log output! Copy everything from the terminal and paste it back to Claude.

## Testing Without the Script

You can also run from Xcode to see logs:

1. Open `radial-menu.xcodeproj` in Xcode
2. Press Cmd+R to run
3. Open the **Debug Area** (View → Debug Area → Show Debug Area)
4. Press Ctrl+Space
5. Watch the Console output (bottom pane)

## Changing the Hotkey

If Ctrl+Space doesn't work, you can try a different key combo.

Edit `AppCoordinator.swift` around line 60:

```swift
// Try Cmd+Shift+Space instead
let success = hotkeyManager.registerHotkey(
    key: HotkeyManager.KeyCode.space,
    modifiers: HotkeyManager.ModifierFlag.command | HotkeyManager.ModifierFlag.shift,
    callback: { [weak self] in
        print("⌨️  Hotkey pressed!")
        self?.viewModel.toggleMenu()
    }
)
```

Rebuild and test!
