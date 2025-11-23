# Radial Menu Overlay

## 1. Product Overview

**Product name**
Radial Menu Overlay for macOS

**Summary**
A lightweight, frameless radial menu that appears on top of the macOS desktop or active app, allowing users to trigger frequently used actions with minimal pointer movement or via a controller shortcut.

**Primary goal**
Reduce time and friction required to execute a small set of common commands (e.g., app switching, macros, system actions) through a visually compact radial menu.

---

## 2. Objectives and Success Metrics

**Objectives**

1. Provide fast access to 4–12 configurable actions from any screen.
2. Keep visual footprint minimal and non-distracting when active.
3. Support both mouse/trackpad and optional game controller input.

**Success metrics**

* Average time from trigger to action execution: ≤ 800 ms for experienced users.
* User can reliably select the intended action ≥ 95% of the time in usability tests.
* Configuration time for a new menu (define items + icons + shortcuts): ≤ 5 minutes.

---

## 3. Target Users and Use Cases

**Target users**

* Power users who use keyboard shortcuts, macros, or automation tools.
* Creators (designers, video editors, developers) with repetitive workflows.
* Users with external controllers wanting quick on-screen actions.

**Key use cases**

1. Quick app/tool commands (e.g., build, run tests, screenshots).
2. System controls (mute/unmute, volume presets, focus mode toggles).
3. Workflow macros (launch app set, arrange windows, run scripts).
4. Controller-driven overlay (press button on controller to pop up radial menu and select action with stick/d-pad).

---

## 4. Scope

**In scope (v1)**

* Single radial menu instance with 4–8 items.
* Desktop overlay window with no visible rectangular frame.
* Custom icons and labels for each menu item.
* Mouse/trackpad selection and activation.
* Basic configuration UI (simple list of items with icon + title + action type).
* Support for common action types:

  * Launch app
  * Run shell command / script
  * Simulate keyboard shortcut
* Global hotkey to open/close menu.

**Out of scope (v1)**

* Multiple different menus/profiles.
* Sync between devices.
* Complex macro editor (conditions, loops, etc.).
* Advanced theming/skins.

---

## 5. Functional Requirements

### 5.1 Trigger and Visibility

1. The user can toggle the radial menu with a global shortcut (e.g., `Ctrl+Space`).
2. The menu appears centered at either:

   * The current cursor position, or
   * A fixed screen position (configurable option).
3. The menu remains visible until:

   * An item is selected, or
   * The user clicks outside the menu / presses Escape.

### 5.2 Radial Menu Behavior

4. Menu items are arranged in a circular layout around the center.
5. Each item shows:

   * Icon (16–64 px, auto scaled).
   * Optional text label.
6. Hovering (or analog stick tilt) highlights the nearest item.
7. Clicking or pressing confirm (e.g., Enter/controller button) on a highlighted item triggers its action and closes the menu.
8. Clicks outside the circular region dismiss the menu without triggering any action.

### 5.3 Configuration

9. The product provides a simple preferences window with:

   * Toggle for “show at cursor” vs “show at fixed position”.
   * Global hotkey configuration.
   * List of menu items with:

     * Title
     * Icon selector
     * Action type (launch app / run command / keyboard shortcut)
     * Action parameters
10. Changes in configuration are applied without app restart.

---

## 6. Non‑Functional / Technical Requirements

To update the Pro Mode–generated PRD, you will need to click the `Update` button on that task and include these new requirements in the prompt. You can copy/paste or adapt the following additions.

---

### Changes to Scope

* Controller input is **in scope for v1** (no longer optional).

---

### New / Updated Functional Requirements

#### 6.2 Layout and Display

* FR‑7 (update): The window is borderless with no title bar or standard OS chrome, and the window background is fully transparent so that only the radial menu graphics are visible.

#### 6.3 Interaction (Mouse)

* FR‑18: While the radial menu is active, all mouse clicks are checked against the circular menu bounds.
* FR‑19: If a mouse click occurs **inside** the radial menu region, it is processed as a menu interaction (e.g., select/activate slice).
* FR‑20: If a mouse click occurs **outside** the radial menu region, the click is ignored by the radial menu window and allowed to fall through to the underlying application (no dismissal, no consumption of the event).

  * Implementation note for engineering: this may require temporarily setting `ignoresMouseEvents = true` or equivalent behavior to pass clicks to underlying windows.

#### 6.3 Interaction (Keyboard)

Add a keyboard subsection:

* FR‑21: Right Arrow key: select the next pie slice in a clockwise direction.
* FR‑22: Left Arrow key: select the next pie slice in a counter‑clockwise direction.
* FR‑23: Esc key: close/dismiss the radial menu without triggering any action.

#### 6.3 Interaction (Controller)

Replace or update the previous “optional” controller section:

* FR‑24: v1 must support controller input for selection and activation:

  * Controller button (configurable) to open/close the radial menu.
  * Analog stick or D‑pad movement to change selection between pie slices.
  * Confirm button (e.g., “A” on common controllers) to trigger the currently selected slice.
* FR‑25: Controller navigation and selection obey the same ordering as keyboard navigation (clockwise/counter‑clockwise).

---

 6.5 Preferences / Menu Bar Integration:

* FR‑26: The application provides a menu bar item (status bar icon) in the macOS top bar.
* FR‑27: Clicking the menu bar icon opens a preferences menu or panel with at least:

  * Enable/disable radial menu.
  * Configure global hotkey.
  * Configure controller button mappings.
  * Open full preferences window for detailed configuration (wedge actions, appearance, etc.).
* FR‑28: The application can be quit from the menu bar icon menu.

---

You can now edit the Pro Mode task’s prompt and insert these requirement blocks so the next generated PRD incorporates controller support in v1, transparent-only radial UI, click‑through behavior outside the menu, the menu bar preferences panel, and the specified keyboard controls.


11. Platform: macOS (version X.Y+; define exact minimum).
12. The radial menu overlay:

    * Uses a borderless, transparent window.
    * Appears above normal app windows (floating level).
    * Can optionally join all Spaces and appear over full‑screen apps (setting).
13. Latency:

    * Time from trigger to menu fully rendered: ≤ 150 ms on a typical machine.
14. Performance:

    * Idle CPU usage near zero when menu is not visible.
15. Accessibility:

    * Keyboard navigation (cycle through items, confirm, cancel).
    * High‑contrast option for icons/labels.

---

## 7. UX / UI Requirements

16. Visual design:

    * Circular layout with evenly spaced segments.
    * Light and dark mode support.
    * Subtle highlight state (color change and/or scale) for hovered item.
17. Animations:

    * Optional, fast fade/scale‑in on open (≤ 150 ms).
    * Optional fade‑out on close (≤ 150 ms).
18. Text:

    * Labels limited to short phrases; truncated with ellipsis if too long.
19. Error handling:

    * If an action fails (e.g., script not found), show a small non‑blocking notification/toast.

---

## 8. Risks and Open Questions

**Risks**

* Conflicts with other global hotkey or overlay tools.
* Security prompts/permissions for executing scripts or simulating keystrokes.

**Open questions**

* Should v1 support controller input, or defer to v2?
* Should there be built‑in action templates (e.g., “mute mic”, “take screenshot”) or only fully custom actions?
* How much theming is required for initial release?

---

## 9. Milestones (Example)

* M1: Prototype radial menu window and interaction (open/close, selection).
* M2: Implement configuration UI and persistence of menu items.
* M3: Implement action execution (apps, shortcuts, commands).
* M4: Add accessibility and theming (dark mode, basic high contrast).
* M5: Beta testing and performance tuning.
* M6: 1.0 release.

You can reuse this structure as a template by replacing the example product and adjusting sections and requirements as needed.
