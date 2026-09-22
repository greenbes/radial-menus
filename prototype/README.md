# Menu and controller architecture prototype

This macOS application implements the first usable part of the design in
[ARCHITECTURE.md](../ARCHITECTURE.md). It displays a radial menu, interprets
controller input, navigates into a submenu, and reports a selected value or a
cancellation. It does not execute the selected value as a command.

The fixed example has Red at the top, Blue on the right, Green at the bottom,
and More colors on the left. More colors opens a submenu containing Amber and
Violet. This is a separate Swift package; it does not import the original app.

## Build and run

Requirements: macOS 14 or later, a Swift 6 toolchain with the macOS SDK, and a
logged-in desktop session for native window checks. Development was verified
with Xcode 27.0 and Swift 6.4 on an Apple silicon Mac. There are no external
package dependencies. Use the command line; the Xcode GUI is unnecessary.

From the repository root:

```sh
./prototype/scripts/test.sh
./prototype/scripts/run.sh
```

The run script builds an app bundle, signs it locally with an ad hoc signature,
and opens its diagnostics window. The menu bar icon provides Open menu, Show
diagnostics, Recover window, and Quit. Closing diagnostics leaves the app
running. Use Quit before rebuilding an already running copy.

The bundle is written to `prototype/build/RadialPrototype.app`. Generated build
files are ignored by Git. This local signature is for development; the script
does not create a distributable or notarized release.

## Controls

| Input | Behavior |
| --- | --- |
| Controller Menu | Open the menu, or cancel the current interaction |
| Left stick | Select the item in that direction |
| D-pad left / right | Select the previous / next item |
| Controller A | Confirm the current selection |
| Controller B | Go back one menu, or cancel at the root |
| Keyboard arrows | Select the previous / next item |
| Return | Confirm the current selection |
| Escape | Go back one menu, or cancel at the root |
| Click an item | Activate that specific item |
| Center button | Go back, or cancel at the root |

Keep the stick deflected while pressing Confirm. Returning the stick to its
center clears a selection made by the stick. It does not clear a selection
made with the keyboard, D-pad, or an accessibility action.

After opening a menu or entering a submenu, release held buttons and center
the stick before selecting again. Holding Confirm across navigation cannot
activate an item in the new menu. A new press is required.

The diagnostics window shows the device name and button labels reported by
macOS. On the connected GuliKit Controller XW, macOS reported A Button,
B Button, a left stick, and a Menu button. A controller without the required
stick and confirmation/back buttons is shown as unsupported. A controller
without Menu can participate after opening the menu from the app.

Background monitoring permits the controller to open the menu while another
app is active. It does not give this app exclusive use of the controller or
disable system behavior associated with reserved buttons.

## Implementation

```text
Sources/
├── RadialCore/        Immutable values, transitions, geometry, presentation
├── RadialRuntime/     Event queue, observable store, effect interfaces
├── RadialMac/         GameController, AppKit window, operation deadlines
├── RadialUI/          SwiftUI menu driven by values and an event callback
└── RadialPrototype/   App composition, diagnostics, native smoke test
```

`RadialCore.update` takes a model and an event and returns a new model, effects,
and outputs. `render` derives the values displayed by SwiftUI. `subscriptions`
describes the controller monitoring and operation deadline currently needed.
These functions do not read the clock or interact with native resources.

The runtime store owns the current model. It processes events synchronously
on the main actor, commits each transition, and then runs its effects. Events
produced by a synchronous native callback enter the queue; they cannot
interrupt the transition being processed. Native APIs are behind three small
interfaces: window operations, controller input, and deadline scheduling.

The window adapter acknowledges presentation only after the SwiftUI content
identifies the current menu and the panel is visible and key. Selecting an
item starts dismissal. The core emits the result after the adapter confirms
that the panel is hidden and any requested focus restoration has finished.
An unsuccessful cleanup produces a failure and blocks further opening until
explicit recovery succeeds.

Session identities reject events from an earlier interaction. Each navigation
also changes the menu revision. Window operation identities are checked both
by the core and before the adapter changes a native window. The app observes
activation notifications when restoring focus; an activation request alone
is insufficient evidence of completion.

The controller adapter uses Apple's buffered physical-input API. Native
objects stay on the main serial queue. It copies each observation into a
value with a connection identity, sequence number, timestamp, input scope,
and continuity indication. Before a new menu accepts input, the adapter
captures a fresh baseline. Lost history invalidates button interpretation and
cancels an interaction owned by that controller.

Current policy values are explicit in the code: stick activation above 0.3,
release at or below 0.2, movement of at least 0.05 from the last accepted
position, a 64-observation native buffer, a 256-event runtime input limit,
and a three-second native-operation deadline. These are prototype choices,
not performance measurements or a completed usability study.

The SwiftUI view emits selection and activation events. Native window
management and controller access do not belong to the view. Its local focus
properties manage UI focus; they do not hold a second copy of menu selection.
Accessibility activation names the item explicitly, so it cannot accidentally
confirm another input source's selection.

## Verification

See [VALIDATION.md](VALIDATION.md) for observed results and their limits.

Run the native checks from an unlocked desktop with the normal prototype
instance closed:

```sh
./prototype/scripts/smoke-test.sh
```

This temporarily opens menus and changes application focus. The script prints
the location of a fresh temporary directory containing `report.json`,
`events.log`, `root-menu.png`, `selected-menu.png`, and `submenu.png`.
It returns failure if the
report is absent, malformed, or unsuccessful. The report distinguishes
scripted input from physical controller operation.

The expected interaction is:

1. Opening creates a pending presentation, with selection disabled.
2. Native content and key-window observations make it active.
3. Selection identifies one item in the current menu.
4. Confirmation starts dismissal without reporting success yet.
5. Native cleanup produces exactly one completed result.

Tests also exercise stale acknowledgments, cancellation while opening,
submenu input baselines, held buttons, competing controllers, malformed or
lost input, reentrant callbacks, queue overflow, cleanup failure, and recovery.
Geometry tests cover every generated sector boundary for 2 through 12 items,
the single-item ring, center exclusion, and negative screen coordinates.
A bounded sequence test visits 9,331 event prefixes through depth five.

For a physical test, use Menu, hold the stick up, and press A to choose Red.
Then open again, hold left and press A for More colors, release the controls,
hold down and press A for Violet. Check the results in diagnostics. Also try
B, D-pad navigation, and disconnecting the controller while its menu is open.

Optional recording, after quitting any running instance:

```sh
./prototype/scripts/run.sh --record /tmp/radial-controller-events.log
```

Recording is explicit and writes controller samples, window observations,
and results to the supplied path. Without this option, recent diagnostics
remain in memory. Recording stops with the app. The file is not rotated;
use this option for short verification sessions.

Apple's older writable `GCController.withExtendedGamepad()` snapshot did not
propagate its values into the newer buffered input API on the verified SDK.
`Probes/LegacyControllerSnapshot.swift` reproduces that observation. It is not
used as a substitute for a physical controller or as evidence that the native
decoder handles button presses correctly.

## Scope and remaining checks

This first prototype includes controller selection, keyboard input, clickable
items, accessibility actions, submenu navigation, window lifecycle, failures,
and diagnostic results. Right-stick repositioning, pointer-hover selection,
configuration editing, persistence, custom icons, global hotkeys, and command
execution are outside this implementation milestone.

Successful automated tests do not establish VoiceOver usability, behavior on
other controller models, exclusive controller delivery, display removal,
Spaces behavior, or focus races with other applications. Those require native
observations. `ARCHITECTURE.md` describes the broader intended architecture;
this prototype is an executable subset, not a claim that every part has been
implemented or verified.
