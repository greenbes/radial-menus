# How to View Logs in Xcode

The logging I added uses `print()` which only shows up in Xcode's debug console, not in the terminal.

## Quick Steps

1. **Open Xcode**:
   ```bash
   open radial-menu.xcodeproj
   ```

2. **Show the Debug Area** (if not visible):
   - Menu: `View → Debug Area → Show Debug Area`
   - Or press: **Cmd+Shift+Y**

3. **Run the app**:
   - Click the ▶️ Play button (or press **Cmd+R**)

4. **Watch the Console** (bottom pane):
   - You should see all the startup logs with emojis:
     ```
     🚀 AppDelegate: Application did finish launching
     📋 AppCoordinator: Starting...
     🔑 HotkeyManager: Attempting to register hotkey...
     ```

5. **Press Ctrl+Space**:
   - Watch for: `🔥 HotkeyManager: HOTKEY EVENT RECEIVED!`

## What You Should See

### At Startup:

```
🚀 AppDelegate: Application did finish launching
🚀 AppDelegate: Coordinator created
📋 AppCoordinator: Starting...
📋 AppCoordinator: Setting up menu bar...
📋 AppCoordinator: Menu bar setup complete
📋 AppCoordinator: Registering global hotkey...
🔑 HotkeyManager: Attempting to register hotkey with key=49, modifiers=...
✅ HotkeyManager: Event handler installed successfully
✅ HotkeyManager: Hotkey registered successfully!    <-- GOOD!
💡 HotkeyManager: Press Ctrl+Space to trigger the menu
✅ Global hotkey registered successfully
...
📋 AppCoordinator: Start complete!
🚀 AppDelegate: Coordinator started
```

**OR** (if permissions missing):

```
❌ HotkeyManager: Failed to register hotkey, status=-50    <-- BAD!
❌ HotkeyManager: This likely means Accessibility permissions are not granted
⚠️  Warning: Failed to register global hotkey
```

### When You Press Ctrl+Space (if working):

```
🔥 HotkeyManager: HOTKEY EVENT RECEIVED!
🔥 HotkeyManager: Calling hotkey callback...
⌨️  Hotkey pressed!
🎯 RadialMenuViewModel: toggleMenu() called, current state: closed
🎯 RadialMenuViewModel: Menu is closed, opening...
🎯 RadialMenuViewModel: Opening menu...
🎯 RadialMenuViewModel: Calculated 4 slices
🎯 RadialMenuViewModel: Showing overlay window...
🔥 HotkeyManager: Callback completed
🎯 RadialMenuViewModel: Transition to open state complete
```

## Quick Diagnosis

| Startup Log | When Pressing Ctrl+Space | Problem | Solution |
|------------|-------------------------|---------|----------|
| ❌ Failed to register hotkey | Nothing | No Accessibility permissions | System Settings → Privacy & Security → Accessibility → Add app |
| ✅ Hotkey registered successfully! | Nothing (no 🔥 message) | Another app capturing hotkey OR Input Monitoring permission | Try different hotkey OR check Input Monitoring permissions |
| ✅ Hotkey registered successfully! | 🔥 HOTKEY EVENT RECEIVED! | All good, menu should appear | If menu doesn't appear, check for window errors in console |

## If You See "Failed to register hotkey"

1. Quit the app (Cmd+Q in Xcode)
2. Open **System Settings**
3. Go to **Privacy & Security → Accessibility**
4. Click the 🔒 to unlock (enter password)
5. Click the **+** button
6. Navigate to `~/Library/Developer/Xcode/DerivedData/radial-menu-.../Build/Products/Debug/radial-menu.app`
7. Add it
8. Run again from Xcode

## Alternative: Console.app

If you prefer not to use Xcode:

1. Open **Console.app** (in /Applications/Utilities/)
2. In the search box, type: `process:radial-menu`
3. Start the app: `open ~/Library/Developer/Xcode/DerivedData/radial-menu-*/Build/Products/Debug/radial-menu.app`
4. Watch Console.app for messages
5. Press Ctrl+Space

But Xcode's console is much cleaner and easier to read!
