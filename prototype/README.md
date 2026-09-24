# Menu and controller architecture prototype

This macOS application implements the first usable part of the design in
[ARCHITECTURE.md](../ARCHITECTURE.md). It displays a radial menu, interprets
controller input, navigates into a submenu, and reports a selected value or a
cancellation. It does not execute the selected value as a command.

The default example contains six illustrative workspace actions with short
labels, full titles, and descriptions. More commands opens the color menu.
These choices only report values; the described actions do not execute.
This is a separate Swift package; it does not import the original app.

Use the **Menu style** dropdown in diagnostics to choose **Full labels**, **Full
labels with icons**, **Floating labels**, **Floating labels — recenter submenus**,
**Cards**, **Selected message**, or
**Pie wedges**. Full labels implements design 1: complete titles surround a
compact ring, with a line
connecting each title to its controller direction. Full labels with icons places
action symbols on the compact ring, leaves the center empty, and omits
connecting lines. Selection fills the icon badge and its title button with the
same accent color and adds a thicker white outline. There is no selection
checkmark in this style; submenu arrows remain visible. Floating labels puts the
icons inside individually sized buttons, with no ring or center control. Titles
wrap at word boundaries after at most 20 characters per line; longer words stay
intact on their own lines. Buttons grow vertically, and their closest rounded
edges touch a common invisible circle. Selection uses an accent fill and thicker
white outline. Launch it with
`./prototype/scripts/run.sh --floating-labels`. Cards implements design 2: each
radial card shows its full title and description, with a tinted outline and
checkmark on selection.
Clicking anywhere on the card, including the description, chooses that item.
Selected message displays short labels tangent to the outside of a ring and the
selected item's
full text in the center. Pie wedges display the short labels inside sectors. All
styles use the same content, item order, navigation, and results. Style
changes apply on the next opening and remain in memory until quitting. A submenu
retains the style of its current interaction. See [menu style behavior and
validation](MENU_STYLES.md) for details.

The original color example remains available with `--color-demo`: Red at the
top, Blue on the right, Green at the bottom, and More colors on the left.
More colors opens Amber and Violet. Automated smoke and shutdown checks use
this fixture.

The menu grows to fit measured labels, including their selected font weight
and submenu indicators. If it cannot fit the available screen without shrinking
text, opening fails explicitly. See [layout validation results](LAYOUT_VALIDATION.md)
for the supported fixture matrix and remaining validation limits.

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

To start with design 1 selected, use `./prototype/scripts/run.sh --full-labels`.
For the icon alternative, use `./prototype/scripts/run.sh --icon-labels`. For
design 2, use `./prototype/scripts/run.sh --cards`.

To explore the first submenu concept with four levels and several branches:

```sh
./prototype/scripts/run.sh --submenu-demo --recentered-submenus
```

Choose **Browse saved commands and shortcuts** at the top, then **Arrange my
windows for this task** at the top, then **Arrange research sources and notes**
on the right. Use the left analog stick to select a direction and bottom **B**
to enter that submenu. Each submenu recenters its full-size choices. Earlier
levels form separate concentric arcs to the left, outside the active menu.
Older levels sit farther from the center and occupy shorter arcs. Their labels
shrink by 20% for each level back: 80% for the parent, 64% for the grandparent,
51.2% for the next ancestor, and progressively smaller thereafter. Text, icons,
padding, and corner radii scale together. Returning to an earlier menu enlarges
those labels again.

Each arc groups an earlier menu's title and its other choices. These muted
labels display history: they have no selection outline, return arrow, or click
action. Use Back to return one level before choosing another branch.

The controller selects only the active full-size choices. Back returns one
level. Release Confirm and center both sticks between levels before choosing
again. On the GuliKit, the bottom button labeled **B** confirms and the right
button labeled **A** goes back. The ordinary Floating labels option remains
available for comparison. `--submenu-demo` also works with the other styles.

This experiment uses distance and scale to distinguish menu levels. It is not
an exact hyperbolic projection. Measured label rectangles occupy separate radial
bands, keeping the history levels apart and active controller directions fixed.
If the complete layout cannot fit the screen, preparation fails explicitly.
Menus enter with a brief scale/fade animation; input waits for its completion.
The system's Reduce Motion setting removes this animation.

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
| Right stick | Move the menu across the connected displays |
| D-pad left / right | Select the previous / next item |
| Confirm button | Confirm the current selection |
| Back button | Go back one menu, or cancel at the root |
| Keyboard arrows | Select the previous / next item |
| Return | Confirm the current selection |
| Delete | Go back one menu, or cancel at the root |
| Escape | Cancel the whole interaction, including from a submenu |
| Pointer movement | Select the item under the pointer |
| Click an item | Activate that specific item |
| Back / Cancel control | Go back, or cancel at the root |

Full labels with icons and both Floating labels variants have no center Back /
Cancel control.

On the tested **GuliKit Controller XW**, the **bottom face button labeled B**
confirms, and the **right face button labeled A** goes back or cancels. macOS
reports these as A and B respectively; the diagnostics window uses those
macOS names. Printed labels can differ from the names reported by macOS.

Keep the stick deflected while pressing Confirm. Returning the stick to its
center clears a selection made by the stick. It does not clear a selection
made with the keyboard, D-pad, pointer, or an accessibility action.

Moving the mouse by at least two logical screen points takes selection from
another input when the pointer is over an item. Smaller movements accumulate
from the last accepted position. Leaving a selectable target clears only a
selection made by the pointer. In Pie wedges, the targets are sectors; in the
other styles, they are the label or card buttons. Rings, separate icon badges,
connecting lines, and central message text are not selectable. Icons inside
Floating labels
are part of the item button and can be clicked. A stationary mouse or stick
does not overwrite a keyboard, D-pad, or other deliberate selection.

Opening or entering a submenu establishes the current pointer position without
selecting an item. Moving the menu beneath a stationary pointer preserves the
selection. Clicking activates the specific clicked item, even if another item
was selected. Controller Back and keyboard Delete return to the parent menu. The
center Back control also does this in styles that show it. Escape cancels the
whole interaction. Full labels with icons and Floating labels expose a named
Back or Cancel action on each accessible item without a center button.

After opening a menu or entering a submenu, release held buttons and center
both sticks before selecting or moving again. Holding Confirm across navigation
cannot activate an item in the new menu. A new press is required.

Disconnecting the controller that opened the menu stops movement and cancels
that interaction. Reconnecting gives the device a new connection identity;
held buttons establish its initial state. Release them before pressing Menu
or Confirm again. An unrelated controller disconnecting does not cancel the
owner's menu. A choice already committed before disconnection is preserved.

Right-stick deflection controls speed: small tilts move slowly, and pushing
toward the edge increases speed more rapidly. Releasing it stops movement.
The menu's position moves continuously across shared display edges. On the
tested Mac, the visible menu jumps between displays; the user accepted this
behavior. Simultaneous visibility on both displays has not been established.
The complete window stays within the combined usable display areas, stopping at
outer edges and gaps. With offset displays, cross where there is enough shared
height or width for the menu. Crossing preserves the menu, selection, and held
stick input. Navigation stops movement until the right stick returns to neutral.
If the display arrangement changes, movement stops and the menu moves to the
nearest position that fits the remaining displays.

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
interrupt the transition being processed. Native APIs are behind five small
interfaces: window operations, text measurement, controller input, deadline
scheduling, and movement ticks.

Opening and navigation first enter a preparation phase. `SwiftUIMenuMeasurer`
measures the shared label components at both font weights and measures the
center control where present. Full labels with icons measures its native symbols
in both selection states and supplies an explicitly empty center. For Selected
message it measures every full message and the neutral instructions, including
the Back button in submenus. Its center has no heading, item counter, or Cancel
button.
The window adapter supplies those immutable sizes
with every display's usable rectangle and the desired center point. It does not
choose radii.

`MenuLayout.make` validates complete measurements by item identity, reserves
the maximum width and height needed by either weight, and calculates a common
label radius. Pie labels and both full-label styles stay within their sectors
and outside the center control or decorative ring. Floating labels instead
places each rounded boundary tangent to an invisible circle, separates all item
rectangles, and reserves a rectangular window from their individual sizes. The
outer radius encloses every rectangle with padding. The same immutable layout
controls drawing, pointer selection, and window size;
controller selection uses its shared angular geometry. Selected message instead
separates each label rectangle from the central message rectangle and reserves
the maximum message height. It increases the calculated ring radius by 10% and
places the closest rounded boundary point of each label on that ring, outside
it. Pointer targets follow the same rounded shapes. Its window encloses those
rectangles and the guide circle with independent width and height. Labels may
cross sector boundaries; the tangent points preserve their controller directions.
Selection cannot resize the window or move the labels.

Layout starts with inner radius 46, outer radius 150, and label radius 100,
then grows as needed. Content padding is 8 points, the center-to-ring gap is
4 points, and window padding is 30 points. Default text is 17 points with a
96-point wrapping width; the default width scales with a requested font size.
Selected message uses a 150-point label wrapping width and a 300-point message
width at the default text size; both scale with requested text size. The label
and message components include their own padding in native measurements.
These are explicit prototype settings, not measured usability requirements.

Preparation has its own operation identity and deadline. Invalid measurements
or insufficient space cause cleanup and a failed result before interaction is
enabled. Cancellation, shutdown, navigation, and later opening invalidate old
measurement replies. Presentation rechecks the observed screen before using
its calculated placement. Screen changes subsequently reuse the measured menu
size or cancel when it no longer fits.

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

Movement has separately validated settings: a radial dead zone of 0.1,
maximum speed of 2,400 logical screen points per second, and a maximum elapsed
step of 0.1 seconds. Beyond the dead zone, the remaining stick travel is mapped
to 0–1 and squared to determine the fraction of maximum speed. At 32.5%, 55%,
77.5%, and 100% of full deflection, speeds are 150, 600, 1,350, and 2,400 points
per second. Diagonal input cannot exceed the maximum speed. Speed depends on
deflection, not how long the stick is held. These values are tuning choices,
not measured usability results.

The core owns the desired frame, velocity, last integration time, and current
movement identity. Input receipt times and movement ticks use the same
monotonic clock. Device event timestamps remain separate and are used to
validate input history. Changes in velocity integrate the elapsed interval
with the previous velocity before adopting the new one.

`Desktop` contains immutable display IDs and usable rectangles in common
desktop coordinates. The pure movement calculation uses their union, including
overlapping displays and negative coordinates. It intersects coverage across
the whole window, then sweeps horizontally and vertically through connected
visible spans. This permits crossing shared edges, slides along outer edges,
and prevents even a large movement step from jumping a gap. The desktop's
bounding rectangle is used for reporting only; it cannot establish visibility
when displays are offset or separated.

The native adapter validates the complete display snapshot before moving the
panel. Crossing onto another display does not replace the snapshot or reset
input. A changed arrangement produces a new layout revision and input baseline.
Submenus retain the current desktop center when their measured size fits there.

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

To reproduce layout validation across item counts and label profiles, run:

```sh
./prototype/scripts/layout-test.sh
./prototype/scripts/layout-test.sh --selected-message
./prototype/scripts/layout-test.sh --full-labels
./prototype/scripts/layout-test.sh --icon-labels
./prototype/scripts/layout-test.sh --cards
./prototype/scripts/layout-test.sh --floating-labels
```

Run `./prototype/scripts/context-test.sh` for the recentering experiment's
native navigation, typography, context bounds, light/dark appearance, and
selection checks. Run `./prototype/scripts/smoke-test.sh --recentered-submenus`
for scripted controller, pointer, movement, and lifecycle checks with that style.
Both require the normal prototype to be closed. These scripted checks do not
replace testing with the physical controller or VoiceOver.

Run `./prototype/scripts/desktop-test.sh` with horizontally adjacent displays
to check continuous movement across their shared edge. The probe moves a
four-level menu onto each display and back, pauses between native movement
steps, and checks selection, focus, neutral release, Back, and confirmation.
It writes the observed frames, display identities, and results to `report.json`
in the printed temporary directory. It requires enough shared usable height
and width to fit that menu completely on either display.

The optional `--desktop-preview` flag pauses at the boundary for up to three
minutes. Wait for `preview-ready.txt` in the reported directory, inspect both
displays, then create `continue.txt` in that directory to resume. Switching
applications dismisses the menu and fails this check. The saved content bitmap
and window coordinates do not establish whether macOS displays the contents on
both monitors simultaneously; that requires direct visual observation.

The commands check 64 pie, 66 selected-message, 68 full-label, 68 icon-label,
69 floating-label, and 81 card fixtures. Every style except Pie wedges includes
the richer demo at two text sizes. Both full-label styles, Floating labels, and
Cards check titles at the 160-character limit; Cards also checks 600-character
descriptions and mixed description lengths. The probes capture native renderings,
check keyboard interaction, and validate measured label rectangles against
each menu's calculated geometry. They also check native pointer selection
and clicking beyond the original ring, and inject an undersized screen
observation to verify failure before display.
The normal prototype must be closed. See
[LAYOUT_VALIDATION.md](LAYOUT_VALIDATION.md) for observed results.

Run the native checks from an unlocked desktop with the normal prototype
instance closed:

```sh
./prototype/scripts/smoke-test.sh
./prototype/scripts/smoke-test.sh --selected-message
./prototype/scripts/smoke-test.sh --full-labels
./prototype/scripts/smoke-test.sh --cards
./prototype/scripts/smoke-test.sh --floating-labels
./prototype/scripts/lifecycle-test.sh
```

This temporarily opens menus and changes application focus. The script prints
the location of a fresh temporary directory containing `report.json`,
`events.log`, `root-menu.png`, `selected-menu.png`, and `submenu.png`.
It returns failure if the report is absent, malformed, or unsuccessful.
The report distinguishes
scripted input from physical controller operation.

The lifecycle script starts eight separate app processes and checks actual
exit, result ordering, and resource observations. It requests quit while idle,
preparing, opening, active, moving, dismissing a committed choice, recovering,
and waiting
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

For Full labels, open the demo and check that every full title is visible.
Select each direction: its label, connection, and ring marker should highlight
together without moving. Use Confirm to choose an item, and Browse saved
commands and shortcuts to enter the color menu. Change the dropdown and reopen
to compare the other styles. Confirm is the bottom button labeled B on the
GuliKit; Back is the right button labeled A.

For Cards, check that all descriptions are visible before selecting anything.
The selected card should gain a light tint, an outline, and a checkmark without
moving. Try clicking its description while a different card is selected; the
clicked card should supply the result. The central button still cancels or
returns to the parent menu.

For the color regression test, run with `--color-demo`, use Menu, hold the
stick up, and press Confirm to choose Red. Then open again, hold left and
press Confirm for More colors, release the
controls, hold down and press Confirm for Violet. Check the results in
diagnostics. Also try Back and D-pad navigation. On the tested GuliKit,
Confirm is the bottom button labeled B and Back is the right button labeled A.

Optional recording, after quitting any running instance:

```sh
./prototype/scripts/run.sh --color-demo --record /tmp/radial-controller-events.jsonl
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
change within the union of recorded display rectangles, a neutral release that
stops movement before confirmation, and a selected result following dismissal.
A manual report or the smoke test's scripted controller values cannot satisfy
this check.

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
