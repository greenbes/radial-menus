# Research Report: Adopting macOS Standard Menu Semantics

## Executive Summary

This report investigates how to make the Radial Menu app comply with Apple's HID and UX guidelines by adopting standard macOS menu semantics and integrating with assistive technologies. The current implementation has **minimal accessibility support** and uses custom key handling that bypasses system standard services.

**Key Finding**: The app should replace custom `keyDown` event processing with `interpretKeyEvents(_:)` and implement standard `NSResponder` action methods (`moveUp:`, `moveDown:`, `cancelOperation:`, etc.) to gain automatic system integration.

---

## Part 1: Current Implementation Analysis

### Codebase Architecture

The app uses Clean Architecture with a Functional Core / Imperative Shell pattern:

| Layer | Components | Accessibility Status |
|-------|------------|---------------------|
| **Domain** | MenuItem, MenuState, RadialGeometry | Pure functions, no accessibility hooks |
| **Infrastructure** | RadialMenuContainerView, OverlayWindowController | NSView-based, custom key handling |
| **Presentation** | RadialMenuView, SliceView (SwiftUI) | No accessibility modifiers |

### Critical Files

- `Infrastructure/Window/RadialMenuContainerView.swift` - Custom NSView handling events
- `Infrastructure/Window/OverlayWindowController.swift` - Window management
- `Presentation/RadialMenu/RadialMenuView.swift` - SwiftUI view hierarchy
- `Presentation/RadialMenu/SliceView.swift` - Individual menu item rendering
- `Domain/Models/MenuItem.swift` - Menu item data model
- `Domain/Models/MenuState.swift` - State machine

### Current Accessibility Gaps

1. **Custom key code handling** - Bypasses system key bindings
2. **No accessibility hierarchy** - Menu items invisible to assistive technologies
3. **No VoiceOver support** - Items have no labels, roles, or announcements
4. **No focus indicators** - Visual selection is purely decorative
5. **No Reduce Motion support** - Animations ignore system preferences

---

## Part 2: Replacing Custom Event Processing with System Standard Services

### Current Custom Key Handling (Problem)

The current implementation in `RadialMenuContainerView.swift:137-157` uses hardcoded key codes:

```swift
// CURRENT: Custom key code handling (NOT recommended)
override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 123: // Left Arrow
        onKeyboardNavigation?(false)
    case 124: // Right Arrow
        onKeyboardNavigation?(true)
    case 36: // Return
        onConfirm?()
    case 53: // Escape
        onCancel?()
    default:
        super.keyDown(with: event)
    }
}
```

**Problems with this approach:**
1. Hardcodes physical key codes - doesn't respect user key binding customizations
2. Bypasses the system's `interpretKeyEvents` mechanism
3. Not accessible to assistive technologies
4. Doesn't support international keyboards properly
5. Can't be discovered or remapped by system accessibility features

### System Standard Services Solution

macOS provides `interpretKeyEvents(_:)` which routes events through the [Text Input Management system](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingKeyEvents/HandlingKeyEvents.html). The system checks key bindings dictionaries and calls standard action methods on your responder.

**Recommended Implementation:**

```swift
// RECOMMENDED: System standard key binding integration
class RadialMenuContainerView: NSView {

    override func keyDown(with event: NSEvent) {
        guard isMenuActive else {
            super.keyDown(with: event)
            return
        }
        // Delegate to system key binding mechanism
        interpretKeyEvents([event])
    }

    // MARK: - NSStandardKeyBindingResponding Methods
    // These are called automatically by interpretKeyEvents based on user's key bindings

    override func moveUp(_ sender: Any?) {
        // Up arrow (or user-remapped key)
        onKeyboardNavigation?(false) // Counter-clockwise toward top
    }

    override func moveDown(_ sender: Any?) {
        // Down arrow (or user-remapped key)
        onKeyboardNavigation?(true) // Clockwise toward bottom
    }

    override func moveLeft(_ sender: Any?) {
        // Left arrow - counter-clockwise
        onKeyboardNavigation?(false)
    }

    override func moveRight(_ sender: Any?) {
        // Right arrow - clockwise
        onKeyboardNavigation?(true)
    }

    override func insertNewline(_ sender: Any?) {
        // Return/Enter key
        onConfirm?()
    }

    override func cancelOperation(_ sender: Any?) {
        // Escape key
        onCancel?()
    }

    // Handle unbound keys gracefully
    override func doCommand(by selector: Selector) {
        if responds(to: selector) {
            perform(selector, with: nil)
        } else {
            // Optionally: play system beep for unhandled keys
            NSSound.beep()
        }
    }
}
```

### Standard Key Bindings Reference

The system maintains key bindings in `/System/Library/Frameworks/AppKit.framework/Resources/StandardKeyBinding.dict`. Users can customize in `~/Library/KeyBindings/DefaultKeyBinding.dict`.

| Action Method | Default Key(s) | Description |
|---------------|----------------|-------------|
| `moveUp:` | ↑, Ctrl+P | Navigate up |
| `moveDown:` | ↓, Ctrl+N | Navigate down |
| `moveLeft:` | ←, Ctrl+B | Navigate left |
| `moveRight:` | →, Ctrl+F | Navigate right |
| `insertNewline:` | Return, Enter | Confirm/Activate |
| `cancelOperation:` | Escape | Cancel/Close |
| `insertTab:` | Tab | Next element |
| `insertBacktab:` | Shift+Tab | Previous element |

### Benefits of System Integration

1. **Respects user customizations** - Users can remap keys via `DefaultKeyBinding.dict`
2. **International keyboard support** - Works correctly with non-US layouts
3. **Accessibility integration** - VoiceOver and Switch Control use these same methods
4. **Full Keyboard Access compatibility** - System focus management works automatically
5. **Consistent with platform** - Behaves like native macOS controls
6. **Less code to maintain** - No hardcoded key codes

### Additional Standard Methods to Consider

For a radial menu with 8 items, consider implementing directional navigation:

```swift
// Navigate to specific positions
override func moveToBeginningOfLine(_ sender: Any?) {
    // Jump to leftmost item (index 6 at 9 o'clock)
    selectItem(at: 6)
}

override func moveToEndOfLine(_ sender: Any?) {
    // Jump to rightmost item (index 2 at 3 o'clock)
    selectItem(at: 2)
}

override func moveToBeginningOfDocument(_ sender: Any?) {
    // Jump to top item (index 0 at 12 o'clock)
    selectItem(at: 0)
}

override func moveToEndOfDocument(_ sender: Any?) {
    // Jump to bottom item (index 4 at 6 o'clock)
    selectItem(at: 4)
}
```

---

## Part 3: macOS Accessibility APIs

### NSAccessibility Protocol (Modern API - macOS 10.10+)

The modern accessibility API uses **protocol-based implementation** rather than the legacy key-based approach.

#### Core Protocols

| Protocol | Purpose | Relevant to Radial Menu |
|----------|---------|------------------------|
| `NSAccessibilityElement` | Base protocol (frame, parent) | Yes - base for all items |
| `NSAccessibilityButton` | Clickable actions | Yes - menu items perform actions |
| `NSAccessibilityGroup` | Container for related items | Yes - the menu container |

#### Key Properties

```swift
// Required for all accessibility elements
var accessibilityRole: NSAccessibility.Role?
var accessibilityLabel: String?
var accessibilityParent: Any?
var accessibilityFrame: NSRect  // or accessibilityFrameInParentSpace

// Optional but recommended
var accessibilityRoleDescription: String?
var accessibilityHelp: String?
var accessibilityChildren: [Any]?
var accessibilityValue: Any?
```

#### Relevant Roles

| Role | Constant | Use Case |
|------|----------|----------|
| Menu | `NSAccessibility.Role.menu` | Container for menu items |
| Menu Item | `NSAccessibility.Role.menuItem` | Individual selectable items |
| Button | `NSAccessibility.Role.button` | Alternative for action items |
| Group | `NSAccessibility.Role.group` | Grouping container |
| Pop Up Button | `NSAccessibility.Role.popUpButton` | Menu trigger |

**Recommendation**: Use `.group` for the container and `.button` (with appropriate labels) for individual slices, since menu items traditionally expect a linear navigation model, while buttons are appropriate for spatially-arranged action triggers.

### Notifications

Accessibility notifications inform assistive technologies of state changes:

```swift
// Key notifications for menu behavior
NSAccessibilityPostNotification(element, .focusedUIElementChanged)  // Selection changed
NSAccessibilityPostNotification(element, .valueChanged)              // State changed
NSAccessibilityPostNotification(element, .layoutChanged)            // Menu opened/closed

// VoiceOver announcements
NSAccessibility.post(
    element: NSApp.mainWindow as Any,
    notification: .announcementRequested,
    userInfo: [
        .announcement: "Menu item 3 of 8: Calendar" as Any,
        .priority: NSAccessibilityPriorityLevel.high.rawValue as Any
    ]
)
```

**Important**: Post announcements with a slight delay (~0.3s) to avoid conflicts with system announcements.

### Creating Accessible Elements Without Views

For the radial menu slices (which are drawn shapes, not individual views):

```swift
class AccessibleSliceElement: NSAccessibilityElement {
    var sliceIndex: Int
    var menuItem: MenuItem

    override var accessibilityRole: NSAccessibility.Role? { .button }
    override var accessibilityLabel: String? { menuItem.title }
    override var accessibilityHelp: String? { actionDescription }
    override var accessibilityParent: Any? { parentContainerView }

    override func accessibilityPerformPress() -> Bool {
        // Execute action
        return true
    }
}
```

---

## Part 4: Apple Human Interface Guidelines

### Menu Design Principles

From Apple's [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/menus):

1. **Reveal on interaction** - Space-efficient command presentation
2. **Predictable placement** - Consistent positioning
3. **Clear visual hierarchy** - Selected/focused state obvious
4. **Keyboard navigable** - Full keyboard support required
5. **Accessible to all** - Works with assistive technologies

### Accessibility Foundations

From Apple's [Accessibility Guidelines](https://developer.apple.com/design/human-interface-guidelines/accessibility):

1. **Support VoiceOver** - All controls must have labels and traits
2. **Provide alternatives** - Visual content needs text descriptions
3. **Respect system settings** - Reduce Motion, Increase Contrast, etc.
4. **Ensure keyboard access** - Every action reachable via keyboard
5. **Test with real users** - Use assistive technologies during development

### Required System Preference Respects

| Setting | Environment Key | Implementation |
|---------|-----------------|----------------|
| Reduce Motion | `@Environment(\.accessibilityReduceMotion)` | Disable/reduce animations |
| Increase Contrast | `@Environment(\.accessibilityInvertColors)` | Enhance visual contrast |
| Reduce Transparency | `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` | Solid backgrounds |
| Differentiate Without Color | `accessibilityDifferentiateWithoutColor` | Add shapes/patterns |

---

## Part 5: Assistive Technologies

### VoiceOver

**Purpose**: Screen reader for visually impaired users

**Integration Requirements**:
- All menu items need `accessibilityLabel` (title)
- Container needs `accessibilityRole = .group`
- Selection changes trigger `.focusedUIElementChanged` notification
- State changes trigger announcements
- Actions implemented via `accessibilityPerformPress()`

**Testing Commands**:
- Toggle: Cmd + F5
- Navigate: Ctrl + Option + Arrow keys
- Activate: Ctrl + Option + Space
- Enter groups: Ctrl + Option + Shift + Down Arrow

### Full Keyboard Access

**Purpose**: Complete keyboard-only navigation (no mouse)

**Integration Requirements**:
- Focus ring visible on selected element
- Tab/Shift-Tab cycles through focusable elements
- Arrow keys navigate within groups
- Space/Return activates
- Escape closes menu

**Current Gap**: The app handles keyboard events manually but doesn't integrate with macOS Full Keyboard Access focus system.

### Switch Control

**Purpose**: For users with limited mobility using adaptive switches

**Integration Requirements**:
- Same as VoiceOver (accessibility hierarchy)
- Efficient grouping (minimize switch presses to reach items)
- Error tolerance (confirmation for destructive actions)
- Auto-scanning support (items must be in logical order)

**Key Insight**: Apps that work with VoiceOver typically work with Switch Control.

### Voice Control

**Purpose**: Hands-free operation via voice commands

**Integration Requirements**:
- Accessibility labels become voice command targets ("click Calendar")
- Grid overlay support (already handled by system)
- Standard control names work automatically

**Voice Control Commands**:
- "Click [item name]" - Activates labeled items
- "Show names" / "Show numbers" - Overlay for interaction
- "Show grid" - Grid-based positioning

---

## Part 6: Input & HID Compliance

### Current Input Methods (Already Compliant)

| Input | Framework | Status |
|-------|-----------|--------|
| Global Hotkey | Carbon Event Manager | Compliant |
| Keyboard | AppKit NSEvent | Needs refactor to use `interpretKeyEvents` |
| Mouse | AppKit NSEvent + Tracking | Compliant |
| Game Controller | GameController Framework | Compliant |

All input is processed through Apple's official frameworks, not raw HID.

### Required Changes for Full Compliance

1. **Replace custom keyDown handling** with `interpretKeyEvents(_:)` + action methods
2. **Expose accessibility hierarchy** via `NSAccessibilityElement` subclasses
3. **Observe system preferences** for motion, contrast, etc.

---

## Part 7: Implementation Recommendations

### Phase 1: System Key Binding Integration

**Goal**: Replace custom key handling with system standard services

**File**: `RadialMenuContainerView.swift`

1. Replace `keyDown` switch statement with `interpretKeyEvents([event])`
2. Implement `NSStandardKeyBindingResponding` methods:
   - `moveUp:`, `moveDown:`, `moveLeft:`, `moveRight:`
   - `insertNewline:` (Return key)
   - `cancelOperation:` (Escape key)
3. Implement `doCommand(by:)` for graceful handling of unbound keys

### Phase 2: Core Accessibility Foundation

**Goal**: Make menu items visible to assistive technologies

1. **Create `AccessibleSliceElement` class**
   - Subclass `NSAccessibilityElement`
   - Implement `NSAccessibilityButton` protocol
   - Expose label, role, help, frame, parent

2. **Modify `RadialMenuContainerView`**
   - Return `false` for `accessibilityIsIgnored()`
   - Implement `accessibilityChildren` returning slice elements
   - Set `accessibilityRole = .group`

3. **Implement notifications**
   - Post `.focusedUIElementChanged` on selection change
   - Post `.layoutChanged` when menu opens/closes
   - Announce selections with `.announcementRequested`

### Phase 3: System Preferences Integration

**Goal**: Respect user accessibility preferences

1. **Reduce Motion**
   ```swift
   @Environment(\.accessibilityReduceMotion) var reduceMotion

   var animation: Animation? {
       reduceMotion ? nil : .easeOut(duration: 0.15)
   }
   ```

2. **High Contrast**
   - Increase border thickness
   - Use system accent colors
   - Ensure sufficient color contrast (WCAG 2.1 AA: 4.5:1)

3. **Focus indicators**
   - Make focus ring visible and customizable
   - Match system focus ring color

### Phase 4: Announcements & Feedback

**Goal**: Rich VoiceOver experience

1. **Menu state announcements**
   - "Radial menu opened, 8 items"
   - "Calendar, button, 3 of 8"
   - "Menu closed"

2. **Action confirmation**
   - "Opening Calendar"
   - "Running command: screenshot"

---

## Part 8: Testing Strategy

### Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| [Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibility-inspector) | Inspect hierarchy, run audits | Xcode → Open Developer Tool |
| VoiceOver | Real screen reader testing | Cmd + F5 |
| Voice Control | Voice command testing | System Settings → Accessibility |
| Switch Control | Switch user simulation | System Settings → Accessibility |

### Automated Testing

```swift
// XCUITest accessibility audit (macOS 14+)
func testAccessibilityCompliance() throws {
    let app = XCUIApplication()
    app.launch()
    // Trigger menu
    try app.performAccessibilityAudit()
}
```

### Manual Testing Checklist

- [ ] VoiceOver can navigate all menu items
- [ ] VoiceOver announces item names and positions
- [ ] VoiceOver can activate items via Ctrl+Option+Space
- [ ] Full Keyboard Access shows focus ring
- [ ] Arrow keys navigate correctly (via system key bindings)
- [ ] Escape closes menu (via `cancelOperation:`)
- [ ] Return activates item (via `insertNewline:`)
- [ ] Voice Control recognizes item names ("Click Calendar")
- [ ] Reduce Motion setting disables animations
- [ ] Accessibility Inspector shows correct hierarchy

---

## Part 9: Code Changes Summary

### Files to Modify

| File | Changes |
|------|---------|
| `RadialMenuContainerView.swift` | Replace `keyDown` switch with `interpretKeyEvents`, add `NSStandardKeyBindingResponding` methods, add accessibility children |
| `RadialMenuViewModel.swift` | Trigger announcements on state changes |
| `SliceView.swift` | Add accessibility modifiers |
| `MenuItem.swift` | Add accessibility label/hint properties |
| `MenuConfiguration.swift` | Add accessibility settings |

### New Files

| File | Purpose |
|------|---------|
| `Infrastructure/Accessibility/AccessibleSliceElement.swift` | Accessibility element for slices |
| `Infrastructure/Accessibility/MenuAccessibilityManager.swift` | Centralized a11y coordination |

---

## Part 10: Game Controller System Services

### System-Level Controller Integration (macOS Ventura+)

The GameController framework provides **automatic system-level integration** for accessibility and customization without requiring app-level code.

#### Built-in System Features (Free for Developers)

By adding the **Game Controllers capability** in Xcode, your app automatically gains:

| Feature | Description | Developer Action |
|---------|-------------|------------------|
| **Input Remapping** | Players can create system-wide and per-app button remappings | None - automatic |
| **Per-App Profiles** | Users customize controls for your specific app | Just add capability |
| **Adaptive Controller Support** | Xbox Adaptive Controller works automatically | None - framework handles |
| **Buddy Controller** | Two controllers paired for assisted play | System Settings feature |
| **SF Symbols Glyphs** | Automatic button icons that update with remaps | Use `sfSymbolsName` property |

#### What You Get for Free

From Apple's [WWDC 2021 - Tap into Virtual and Physical Game Controllers](https://developer.apple.com/videos/play/wwdc2021/10081/):

> "Players can create system-wide and per-application game controller input remappings, which help make your games more customizable and more accessible. You don't have to do anything to participate in input remapping, but when you tag your game, players can customize it specifically."

#### Accessing System Settings

Users access controller settings via: **System Settings → Game Controllers**

Available options:
- Button/stick remapping per app
- Sensitivity adjustments
- Custom profiles
- Buddy Controller pairing

#### Current Implementation Status

The radial menu app **already uses GameController framework** correctly in `ControllerInputManager.swift`. The app will automatically participate in system-level remapping once the Game Controllers capability is added.

**Recommended Action**: Add the Game Controllers capability in Xcode project settings to enable per-app customization visibility.

#### Controller Accessibility Best Practices

1. **Use `sfSymbolsName` for glyphs**
   ```swift
   // Display correct button icon even after user remapping
   let buttonGlyph = controller.extendedGamepad?.buttonA.sfSymbolsName
   // Returns correct symbol for whatever physical button is mapped
   ```

2. **Support Xbox Adaptive Controller** - Already supported through GameController framework

3. **Consider Buddy Controller users** - Don't assume single-player controller input

---

## Part 11: SwiftUI Accessibility Modifiers

### Core Accessibility Modifiers

SwiftUI provides declarative accessibility modifiers that integrate with system assistive technologies.

#### Basic Modifiers

```swift
// For SliceView.swift
struct SliceView: View {
    let item: MenuItem
    let isSelected: Bool

    var body: some View {
        sliceContent
            // Core accessibility
            .accessibilityLabel(item.title)
            .accessibilityHint(item.actionDescription)
            .accessibilityAddTraits(.isButton)

            // Selection state
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            // Custom actions
            .accessibilityAction(.default) {
                executeAction(item)
            }
    }
}
```

#### Key SwiftUI Accessibility Modifiers

| Modifier | Purpose | Example |
|----------|---------|---------|
| `.accessibilityLabel(_:)` | VoiceOver reads this | `"Calendar"` |
| `.accessibilityHint(_:)` | Explains what happens | `"Opens Calendar app"` |
| `.accessibilityValue(_:)` | Current state value | `"Selected"` |
| `.accessibilityAddTraits(_:)` | Semantic meaning | `.isButton`, `.isSelected` |
| `.accessibilityAction(_:_:)` | Actionable interaction | Default press action |
| `.accessibilityHidden(_:)` | Hide from VoiceOver | Decorative elements |

#### Focus Management with @FocusState

SwiftUI provides focus management that integrates with Full Keyboard Access:

```swift
struct RadialMenuView: View {
    @FocusState private var focusedSlice: Int?

    var body: some View {
        ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
            SliceView(item: items[index], isSelected: index == selectedIndex)
                .focusable()
                .focused($focusedSlice, equals: index)
        }
        .onAppear {
            // Set initial focus
            focusedSlice = selectedIndex
        }
    }
}
```

#### AccessibilityFocusState for VoiceOver

For VoiceOver-specific focus management (separate from keyboard focus):

```swift
struct RadialMenuView: View {
    @AccessibilityFocusState private var accessibilityFocus: Int?

    var body: some View {
        ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
            SliceView(item: items[index])
                .accessibilityFocused($accessibilityFocus, equals: index)
        }
        .onChange(of: selectedIndex) { _, newIndex in
            accessibilityFocus = newIndex  // Move VoiceOver focus
        }
    }
}
```

#### Respecting System Preferences

```swift
struct RadialMenuView: View {
    // System accessibility preferences
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor

    var menuAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.15)
    }

    var backgroundColor: Color {
        reduceTransparency ? .black : .black.opacity(0.8)
    }

    var selectionIndicator: some View {
        Group {
            if differentiateWithoutColor {
                // Use shapes/patterns instead of color alone
                selectedSliceWithPattern
            } else {
                selectedSliceHighlight
            }
        }
    }
}
```

### SwiftUI + AppKit Accessibility Bridge

Since the app uses `NSHostingView` to embed SwiftUI in `RadialMenuContainerView`, accessibility information flows between layers:

```
RadialMenuContainerView (NSView)
    ├── accessibilityRole = .group
    ├── accessibilityChildren = [AccessibleSliceElement...]
    └── NSHostingView
            └── RadialMenuView (SwiftUI)
                    └── SliceView with .accessibilityLabel, etc.
```

**Important**: SwiftUI accessibility modifiers expose elements to the accessibility hierarchy automatically. However, for complex custom views embedded in AppKit, you may need to also implement AppKit accessibility on the container.

### Custom Accessibility Representation

For complex custom views, use `accessibilityRepresentation` to describe behavior using standard controls:

```swift
struct SliceView: View {
    var body: some View {
        customSliceShape
            .accessibilityRepresentation {
                Button(item.title) {
                    executeAction(item)
                }
            }
    }
}
```

This tells VoiceOver to treat the custom shape as if it were a standard button.

### Focus Ring Styling (macOS)

macOS shows focus rings for keyboard navigation. To customize:

```swift
struct SliceView: View {
    @FocusState private var isFocused: Bool

    var body: some View {
        sliceContent
            .focusable()
            .focused($isFocused)
            .overlay {
                if isFocused {
                    // Custom focus ring
                    sliceOutline
                        .stroke(Color.accentColor, lineWidth: 3)
                }
            }
    }
}
```

**Note**: Since macOS Sonoma, the `.focusable()` modifier behavior changed. Verify behavior and potentially add `interactions: .edit` or `.activate` argument if needed.

---

## References

### Apple Documentation

- [Handling Key Events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingKeyEvents/HandlingKeyEvents.html)
- [interpretKeyEvents(_:)](https://developer.apple.com/documentation/appkit/nsresponder/1531599-interpretkeyevents)
- [NSStandardKeyBindingResponding](https://developer.apple.com/documentation/appkit/nsstandardkeybindingresponding)
- [Accessibility Programming Guide for OS X](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/)
- [NSAccessibility Protocol](https://developer.apple.com/documentation/appkit/nsaccessibility)
- [Human Interface Guidelines - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

### WWDC Sessions

- [WWDC 2010 Session 145 - Key Event Handling in Cocoa Applications](https://asciiwwdc.com/2010/sessions/145)
- [WWDC 2014 Session 207 - Accessibility on OS X](https://asciiwwdc.com/2014/sessions/207)
- [WWDC 2019 - Supporting New Game Controllers](https://developer.apple.com/videos/play/wwdc2019/616/)
- [WWDC 2020 - Advancements in Game Controllers](https://developer.apple.com/videos/play/wwdc2020/10614/)
- [WWDC 2020 - App accessibility for Switch Control](https://developer.apple.com/videos/play/wwdc2020/10019/)
- [WWDC 2021 - Tap into Virtual and Physical Game Controllers](https://developer.apple.com/videos/play/wwdc2021/10081/)
- [WWDC 2023 - Perform accessibility audits for your app](https://developer.apple.com/videos/play/wwdc2023/10035/)
- [WWDC 2023 - The SwiftUI cookbook for focus](https://developer.apple.com/videos/play/wwdc2023/10162/)
- [WWDC 2024 - Catch up on accessibility in SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10073/)

### Support Documentation

- [Navigate your Mac using Full Keyboard Access](https://support.apple.com/guide/mac-help/navigate-your-mac-using-full-keyboard-access-mchlc06d1059/mac)
- [Use Voice Control on your Mac](https://support.apple.com/en-us/102225)
- [Use Switch Control on Mac](https://support.apple.com/guide/accessibility-mac/use-switch-control-mh43607/mac)

---

## Conclusion

Implementing macOS standard menu semantics for the Radial Menu app requires:

1. **Replacing custom key handling** with `interpretKeyEvents(_:)` and standard `NSResponder` action methods
2. **Exposing the accessibility hierarchy** via `NSAccessibilityElement` subclasses
3. **Adopting appropriate roles** (`.group` for container, `.button` for items)
4. **Posting notifications** for state changes and selections
5. **Respecting system preferences** for Reduce Motion, High Contrast, etc.
6. **Testing with real assistive technologies**, not just automated audits

The existing Clean Architecture makes these changes straightforward to implement without disrupting the core domain logic. The primary changes are in `RadialMenuContainerView` (replacing custom key handling) and adding an accessibility layer in Infrastructure.
