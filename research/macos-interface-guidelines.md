# Research Report: Adopting macOS Standard Menu Semantics

## Executive Summary

This report investigates how to make the Radial Menu app comply with Apple's HID and UX guidelines by adopting standard macOS menu semantics and integrating with assistive technologies. The current implementation has **minimal accessibility support** and does not expose menu items to the accessibility hierarchy, making it invisible to VoiceOver, Switch Control, and Voice Control users.

---

## Part 1: Current Implementation Analysis

### Codebase Architecture

The app uses Clean Architecture with a Functional Core / Imperative Shell pattern:

| Layer | Components | Accessibility Status |
|-------|------------|---------------------|
| **Domain** | MenuItem, MenuState, RadialGeometry | Pure functions, no accessibility hooks |
| **Infrastructure** | RadialMenuContainerView, OverlayWindowController | NSView-based, no NSAccessibility implementation |
| **Presentation** | RadialMenuView, SliceView (SwiftUI) | No accessibility modifiers |

### Critical Files

- `Infrastructure/Window/RadialMenuContainerView.swift` - Custom NSView handling events
- `Infrastructure/Window/OverlayWindowController.swift` - Window management
- `Presentation/RadialMenu/RadialMenuView.swift` - SwiftUI view hierarchy
- `Presentation/RadialMenu/SliceView.swift` - Individual menu item rendering
- `Domain/Models/MenuItem.swift` - Menu item data model
- `Domain/Models/MenuState.swift` - State machine

### Current Accessibility Gaps

1. **No accessibility hierarchy** - Menu items are not exposed to assistive technologies
2. **No VoiceOver support** - Items have no labels, roles, or announcements
3. **No focus indicators** - Visual selection is purely decorative
4. **No state announcements** - Menu open/close/selection not communicated
5. **No Reduce Motion support** - Animations play regardless of system preferences
6. **No Full Keyboard Access integration** - Custom keyboard handling bypasses system

---

## Part 2: macOS Accessibility APIs

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

**Recommendation**: Use `.menu` for the container and `.button` (with appropriate labels) for individual slices, since menu items traditionally expect a linear navigation model, while buttons are appropriate for spatially-arranged action triggers.

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

## Part 3: Apple Human Interface Guidelines

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

## Part 4: Assistive Technologies

### VoiceOver

**Purpose**: Screen reader for visually impaired users

**Integration Requirements**:
- All menu items need `accessibilityLabel` (title)
- Container needs `accessibilityRole = .menu` or `.group`
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

## Part 5: Input & HID Compliance

### Current Input Methods (Already Compliant)

| Input | Framework | Status |
|-------|-----------|--------|
| Global Hotkey | Carbon Event Manager | Compliant |
| Keyboard | AppKit NSEvent | Compliant |
| Mouse | AppKit NSEvent + Tracking | Compliant |
| Game Controller | GameController Framework | Compliant |

All input is processed through Apple's official frameworks, not raw HID.

### Required Additions for Full Compliance

1. **Accessibility API integration** - Expose elements to system
2. **Responder chain participation** - Proper focus management
3. **System preference observation** - Motion, contrast, etc.

---

## Part 6: Implementation Recommendations

### Phase 1: Core Accessibility Foundation

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

### Phase 2: System Preferences Integration

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

### Phase 3: Enhanced Keyboard Navigation

**Goal**: Full Keyboard Access compatibility

1. **Integrate with responder chain**
   - Proper `makeFirstResponder` management
   - Focus ring visible on selected slice

2. **Standard key bindings**
   - Tab/Shift-Tab: Exit menu / Move to next group
   - Arrow keys: Navigate between items
   - Space/Return: Activate
   - Escape: Close

### Phase 4: Announcements & Feedback

**Goal**: Rich VoiceOver experience

1. **Menu state announcements**
   - "Radial menu opened, 8 items"
   - "Calendar, button, 3 of 8"
   - "Menu closed"

2. **Action confirmation**
   - "Opening Calendar"
   - "Running command: screenshot"

3. **Error announcements**
   - "Action failed: permission denied"

---

## Part 7: Testing Strategy

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
- [ ] VoiceOver can activate items
- [ ] Full Keyboard Access shows focus ring
- [ ] Arrow keys navigate correctly
- [ ] Voice Control recognizes item names
- [ ] Reduce Motion setting disables animations
- [ ] Accessibility Inspector shows correct hierarchy

---

## Part 8: Code Changes Summary

### New Files

| File | Purpose |
|------|---------|
| `Infrastructure/Accessibility/AccessibleSliceElement.swift` | Accessibility element for slices |
| `Infrastructure/Accessibility/MenuAccessibilityManager.swift` | Centralized a11y coordination |
| `Domain/Models/AccessibilitySettings.swift` | User a11y preferences |

### Modified Files

| File | Changes |
|------|---------|
| `RadialMenuContainerView.swift` | Add accessibility children, notifications |
| `RadialMenuViewModel.swift` | Trigger announcements on state changes |
| `SliceView.swift` | Add accessibility modifiers |
| `MenuItem.swift` | Add accessibility label/hint properties |
| `MenuConfiguration.swift` | Add accessibility settings |
| `AppearanceSettings.swift` | Add focus indicator properties |

---

## References

### Apple Documentation

- [Accessibility Programming Guide for OS X](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/)
- [NSAccessibility Protocol](https://developer.apple.com/documentation/appkit/nsaccessibility)
- [Human Interface Guidelines - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Human Interface Guidelines - Menus](https://developer.apple.com/design/human-interface-guidelines/menus)

### WWDC Sessions

- [WWDC 2014 Session 207 - Accessibility on OS X](https://asciiwwdc.com/2014/sessions/207)
- [WWDC 2020 - App accessibility for Switch Control](https://developer.apple.com/videos/play/wwdc2020/10019/)
- [WWDC 2023 - Perform accessibility audits for your app](https://developer.apple.com/videos/play/wwdc2023/10035/)

### Support Documentation

- [Navigate your Mac using Full Keyboard Access](https://support.apple.com/guide/mac-help/navigate-your-mac-using-full-keyboard-access-mchlc06d1059/mac)
- [Use Voice Control on your Mac](https://support.apple.com/en-us/102225)
- [Use Switch Control on Mac](https://support.apple.com/guide/accessibility-mac/use-switch-control-mh43607/mac)

---

## Conclusion

Implementing macOS standard menu semantics for the Radial Menu app requires:

1. **Exposing the accessibility hierarchy** via `NSAccessibilityElement` subclasses
2. **Adopting appropriate roles** (`.group` for container, `.button` for items)
3. **Posting notifications** for state changes and selections
4. **Respecting system preferences** for Reduce Motion, High Contrast, etc.
5. **Testing with real assistive technologies**, not just automated audits

The existing Clean Architecture makes these changes straightforward to implement without disrupting the core domain logic. The accessibility layer would be added primarily in the Infrastructure layer, with minimal changes to Domain models (adding accessibility label/hint fields) and Presentation (SwiftUI accessibility modifiers).
