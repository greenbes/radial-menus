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
| Right stick | Move the complete menu within its assigned screen |
| D-pad left / right | Select the previous / next item |
| Confirm button | Confirm the current selection |
| Back button | Go back one menu, or cancel at the root |
| Keyboard arrows | Select the previous / next item |
| Return | Confirm the current selection |
| Escape | Cancel the whole interaction, including from a submenu |
| Pointer movement | Select the item under the pointer |
| Click an item | Activate that specific item |
| Center button | Go back, or cancel at the root |

On the tested **GuliKit Controller XW**, the **bottom face button labeled B**
confirms, and the **right face button labeled A** goes back or cancels. macOS
reports these as A and B respectively; the diagnostics window uses those
macOS names. Printed labels can differ from the names reported by macOS.

Keep the stick deflected while pressing Confirm. Returning the stick to its
center clears a selection made by the stick. It does not clear a selection
made with the keyboard, D-pad, pointer, or an accessibility action.

Moving the mouse by at least two logical screen points takes selection from
another input when the pointer is over an item. Smaller movements accumulate
from the last accepted position. Leaving the ring or entering its center clears
only a selection made by the pointer. A stationary mouse or stick does not
overwrite a keyboard, D-pad, or other deliberate selection.

Opening or entering a submenu establishes the current pointer position without
selecting an item. Moving the menu beneath a stationary pointer preserves the
selection. Clicking activates the specific clicked item, even if another item
was selected. The controller Back button and center Back control return to the
parent menu; Escape cancels the whole interaction.

After opening a menu or entering a submenu, release held buttons and center
both sticks before selecting or moving again. Holding Confirm across navigation
cannot activate an item in the new menu. A new press is required.

Disconnecting the controller that opened the menu stops movement and cancels
that interaction. Reconnecting gives the device a new connection identity;
held buttons establish its initial state. Release them before pressing Menu
or Confirm again. An unrelated controller disconnecting does not cancel the
owner's menu. A choice already committed before disconnection is preserved.

Right-stick deflection controls speed. Releasing it stops movement. The menu
stays inside its assigned screen's usable area and does not cross onto another
screen. Moving the menu preserves selection. Navigation stops movement until
the right stick has returned to neutral. If the assigned screen disappears,
the adapter chooses an available screen and reports its new bounds to the core.

The diagnostics window shows the device name and button labels reported by
macOS. On the connected GuliKit Controller XW, macOS reported A Button,
B Button, both sticks, and a Menu button. A controller without the required
stick and confirmation/back buttons is shown as unsupported. A controller
without Menu can participate after opening the menu from the app.
Without a right stick, selection remains available but movement is unavailable.

Closing the menu while a wedge remains highlighted does not by itself establish
confirmation; check diagnostics for a selected result.

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
interrupt the transition being processed. Native APIs are behind four small
interfaces: window operations, controller input, deadline scheduling, and
movement ticks.

The window adapter acknowledges presentation only after the SwiftUI content
identifies the current menu and the panel is visible and key. Selecting an
item starts dismissal. The core emits the result after the adapter confirms
that the panel is hidden and any requested focus restoration has finished.
An unsuccessful cleanup produces a failure and blocks further opening until
explicit recovery succeeds.

Application shutdown is a separate core state transition. It disables new
interactions, stops controller monitoring and movement, and completes any
session cleanup before requesting final window-resource release. Only an
acknowledgment of that release produces successful shutdown. A four-second
overall deadline produces an explicit failure if cleanup does not finish;
repeated quit requests do not extend it. A committed choice remains attached
to its session result, including a cleanup failure. These cooperative deadlines
require a responsive main thread.

The AppKit delegate waits for the shutdown result before permitting process
termination. Quit requests originating in Swift tasks or dispatch callbacks
enter AppKit through the main run loop, allowing its termination loop to
continue processing cleanup tasks and the final reply.

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

Movement has separately validated settings: a radial dead zone of 0.2,
maximum speed of 600 logical screen points per second, and a maximum elapsed
step of 0.1 seconds. Diagonal input cannot exceed the maximum speed. These
values are initial tuning choices, not measured usability results.

The core owns the desired frame, velocity, last integration time, and current
movement identity. Input receipt times and movement ticks use the same
monotonic clock. Device event timestamps remain separate and are used to
validate input history. Changes in velocity integrate the elapsed interval
with the previous velocity before adopting the new one.

The runtime subscribes to approximately 60 movement ticks per second while
movement is active. The core integrates elapsed time rather than counting
ticks. Native timer accuracy is not assumed. A long pause contributes at most
the maximum elapsed step; the discarded interval is not recovered later.

Only one native movement request is outstanding at a time. Further ticks
accumulate a desired position. An acknowledgment reports the actual frame,
and the core carries forward displacement accumulated while waiting. A
missing acknowledgment keeps its original deadline instead of indefinitely
renewing it. Neutral release supersedes pending movement with a newer
operation. Navigation and dismissal also invalidate older operations.

Screen observations carry a layout revision. A changed screen resets movement
and its input baseline while preserving selection. Both the core and window
adapter reject obsolete movement identities, operations, and screen layouts
at their respective boundaries.

The window adapter owns a pointer adapter while the panel is presented. It
copies mouse events into immutable observations containing desktop and
menu-relative positions, a sequence number, a timestamp, and a layout revision.
Desktop positions come from the native event's global coordinates, so queued
events do not acquire an apparent displacement when the window moves. The core
compares desktop positions for deliberate motion and uses menu-relative
positions for ring hit testing. The two-point threshold is a validated setting,
not a measured usability result.

Presentation and screen changes establish a pointer baseline without changing
selection. Obsolete sessions, menu revisions, layouts, sequences, and timestamps
cannot update pointer state. Navigation, dismissal, and recovery remove native
pointer monitoring; every newly presented menu starts monitoring with a fresh
baseline. Pointer observation does not require a global event monitor.

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
./prototype/scripts/lifecycle-test.sh
```

This temporarily opens menus and changes application focus. The script prints
the location of a fresh temporary directory containing `report.json`,
`events.log`, `root-menu.png`, `selected-menu.png`, and `submenu.png`.
It returns failure if the report is absent, malformed, or unsuccessful.
The report distinguishes
scripted input from physical controller operation.

The lifecycle script starts seven separate app processes and checks actual
exit, result ordering, and resource observations. It requests quit while idle,
opening, active, moving, dismissing a committed choice, recovering, and waiting
for a withheld final acknowledgment. An explicit test adapter holds selected
acknowledgments to make these brief states observable; native window operations
still run. The recovery case also injects a cleanup failure. These injected
conditions do not establish how often native failures occur.
See [LIFECYCLE_TESTS.md](LIFECYCLE_TESTS.md) for the expected traces.

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
Movement tests compare one-second traces at 30, 60, and 120 ticks per second,
irregular intervals, velocity changes, neutral release, and long gaps. They
also cover clamping, stale ticks, competing controllers, pending requests,
actual-frame acknowledgments, screen changes, and subscription cleanup.
The test script also runs the Python recording verifier's positive and
negative fixtures.

For a physical test, use Menu, hold the stick up, and press Confirm to choose
Red. Then open again, hold left and press Confirm for More colors, release the
controls, hold down and press Confirm for Violet. Check the results in
diagnostics. Also try Back and D-pad navigation. On the tested GuliKit,
Confirm is the bottom button labeled B and Back is the right button labeled A.

Optional recording, after quitting any running instance:

```sh
./prototype/scripts/run.sh --record /tmp/radial-controller-events.jsonl
```

For a movement recording, press Menu, move with the right stick, release it
while the menu remains open, then hold the left stick up and press Confirm
for Red.
Verify the resulting recording with:

```sh
python3 prototype/scripts/verify-recording.py \
    /tmp/radial-controller-events.jsonl --controller 'GuliKit Controller XW'
```

The verifier requires input from the named controller, an observed frame
change within screen bounds, a neutral release that stops movement before
confirmation, and a selected result following dismissal. A manual report or
the smoke test's scripted controller values cannot satisfy this check.

For Bluetooth reconnection, open the menu, move it with the right stick, and
power off the controller using its hardware controls. Avoid switching apps,
which would cancel through focus loss. After the menu closes, reconnect,
release the controls, press Menu, and choose Red with the left stick and
Confirm. Check the recording with:

```sh
python3 prototype/scripts/verify-reconnection.py \
    /tmp/radial-controller-events.jsonl --controller 'GuliKit Controller XW'
```

This requires physical movement from the named controller, one controller-loss
cancellation, a new connection identity, a fresh Menu input, and one confirmed
Red result after dismissal. It reports whether movement was still active when
disconnection arrived and which buttons were observed at reconnection.

Recording is explicit and writes JSON lines containing controller samples,
core transitions, actual frames, window observations, and results to the
supplied path. Without this option, recent diagnostics
remain in memory. Recording stops with the app. The file is not rotated;
use this option for short verification sessions.

Apple's older writable `GCController.withExtendedGamepad()` snapshot did not
propagate its values into the newer buffered input API on the verified SDK.
`Probes/LegacyControllerSnapshot.swift` reproduces that observation. It is not
used as a substitute for a physical controller or as evidence that the native
decoder handles button presses correctly.

## Scope and remaining checks

This prototype includes controller selection, keyboard input, pointer-hover
selection, clickable items, accessibility actions, submenu navigation,
right-stick repositioning, window lifecycle, failures, and diagnostic results.
Configuration editing, persistence, custom icons, global hotkeys, and command
execution are outside this implementation milestone.

Successful automated tests do not establish VoiceOver usability, behavior on
other controller models, exclusive controller delivery, display removal,
Spaces behavior, or focus races with other applications. Those require native
observations. `ARCHITECTURE.md` describes the broader intended architecture;
this prototype is an executable subset, not a claim that every part has been
implemented or verified.
