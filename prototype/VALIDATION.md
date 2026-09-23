# Prototype validation

These results apply to the fixed example menu and the recorded environment;
they do not establish support for every device or desktop setup.

## Measured layout milestone: 2026-09-23

**All 64 native layout fixtures passed:** the original 62 presentations plus
two at double text size. The original fixed layout failed 50 of 62 fixtures.
The core now derives menu dimensions from native text measurements and screen
bounds. Representative native images show full labels without the earlier
truncation and overlap.

- **87 XCTest tests passed:** 79 core, 7 runtime, and 1 native operation-order
  test. New tests cover measured geometry, preparation, stale observations,
  cancellation, timeout, screen fit, and pointer selection in enlarged menus.
- **18 Python verifier tests passed**, including deliberate overflow, overlap,
  wrong-size, missing-observation, and incomplete-interaction cases.
- **410 native keyboard steps and 63 keyboard-confirmed interactions passed.**
  The parent-to-child transition is included in those interactions.
- Native hover and clicking selected the expected item beyond the old ring.
  An injected 100-by-100-point screen observation produced an explicit failure,
  with no presentation request or selected result, and released resources.
- All **35 existing native interaction assertions** and **eight process shutdown
  cases** passed, including shutdown while preparation's reply was withheld.
- Three deliberately broken temporary variants compiled and failed their
  intended assertions: removing sector containment, restoring the fixed pointer
  radius, and accepting obsolete measurement replies. The unmodified temporary
  control passed its complete core suite.

See [LAYOUT_VALIDATION.md](LAYOUT_VALIDATION.md) for the fixture matrix,
geometry policy, visual findings, and limits. New artifacts are retained under
`build/verification/measured-layout/`; the original failing baseline remains
under `build/verification/layout/`. Both directories are excluded from Git.
This milestone does not establish VoiceOver usability or a new physical
controller test.

## Controller lifecycle and shutdown milestone: 2026-09-23

On the same macOS 27.0, Xcode 27.0, and Swift 6.4 environment:

- **74 XCTest tests passed:** 66 core tests, 7 runtime tests, and 1 native
  operation-order test. Eleven new core tests cover shutdown and reconnection;
  two new runtime tests cover cleanup ordering and the overall deadline.
- **Ten Python recording-verifier tests passed.** Positive and negative
  fixtures cover movement, reconnection, and shutdown. Missing evidence,
  contradictory results, resource leaks, wrong ordering, and early or late
  shutdown deadlines are rejected.
- **35 native menu assertions passed.** The additional five use controller
  value fixtures with a real panel and movement timer to check disconnection,
  fresh connection histories, held-button baselines, and obsolete callbacks.
- **Seven separate application processes passed shutdown checks.** The script
  observed their starting states, termination requests, terminal results,
  resource state, AppKit termination notification, and process exit.
- **Two deliberately broken variants failed their intended assertions.**
  Accepting an obsolete resource-release reply failed the acknowledgment test.
  Discarding a committed choice at the shutdown deadline failed the choice
  preservation test. Both variants compiled before failing.

The process cases start idle, opening, active, moving, dismissing a committed
Blue choice, recovering, or waiting for a withheld resource-release reply.
The test adapter holds selected acknowledgments and injects a cleanup failure
for the recovery case. Native window operations still run. The missing-reply
case reached the real overall deadline and reported failed shutdown; the
observed interval from quit request to termination notification was about
4.24 seconds. This is a recorded timeout check, not a latency benchmark.

Every process recorded no remaining panel, pointer monitoring, window or
controller observers, input handlers, movement timers, or operation deadlines
at termination. The controller background-monitoring setting was restored.
Session completion preceded shutdown completion, and the committed Blue
choice survived a quit request during dismissal. A prior cleanup failure
remained a session failure even when final resource release succeeded.

The first process probe found an actual termination hang after successful
cleanup. Calling AppKit termination from inside a Swift task left the task
on the stack while AppKit entered its termination loop; the deferred reply
did not execute. Routing the request through the main run loop allowed that
task to return first. All seven process cases passed with the corrected path.

A further regression test exposed loss of a committed choice if the operation
identity counter is exhausted during shutdown. The test failed before the
fix; exhaustion now preserves the choice in the terminal failure.

**Physical Bluetooth disconnection and reconnection passed** with the
GuliKit Controller XW. Connections 1 and 2 each opened a menu, moved the native
panel, and disconnected. Sessions 1 and 2 each produced exactly one
`controllerLost` cancellation after dismissal. Connection 3 received a fresh
Menu input and a physical Confirm press; session 3 returned Red exactly once.
The user confirmed that both requested behaviors worked. The verifier matched
the complete sequence from connection 2 to connection 3.

Both disconnects were preceded by neutral stick observations. The physical
recording therefore establishes cancellation and fresh interaction after
reconnection; it does not establish stopping an active movement timer at the
instant of disconnection. The scripted native check covers that case. All
physical reconnection baselines observed no held buttons, so the held-button
case remains supported by deterministic and scripted checks only.

After the physical test, a normal termination signal exercised the production
quit path with the GuliKit connected. It recorded successful resource release,
no remaining input handlers or native resources, restored background
monitoring, and AppKit's termination notification. Multiple physical
controllers, VoiceOver, display removal, and Spaces remain outside these
results.

Artifacts are saved locally under `build/verification/lifecycle/`, including
native process recordings and reports, menu smoke results, test output, and
mutation results. They are excluded from Git.

## Pointer and mixed-input milestone: 2026-09-23

On the same macOS 27.0, Xcode 27.0, and Swift 6.4 environment:

- **61 XCTest tests passed:** 55 core tests, including 16 new pointer tests,
  5 runtime tests, and 1 native operation-order test.
- **Three Python recording-verifier tests passed.** These remain checks of
  the movement recording verifier, not additional pointer tests.
- **30 native smoke assertions passed.** App-local mouse and keyboard events
  exercised the real panel, pointer adapter, SwiftUI buttons, and dismissal.
  Controller value fixtures supplied the scripted mixed-input sequences.
- **Two deliberately broken variants failed their intended assertions.**
  Using menu-relative coordinates to detect pointer movement failed the
  stationary-pointer test. Removing the menu identity check failed the stale
  navigation-event test. Both variants compiled before failing assertions.

Core tests cover cardinal positions and ring boundaries, gradual motion,
configurable thresholds, missing and invalid baselines, device handoffs,
stationary inputs, invalid and obsolete observations, screen changes, clicks
on an item other than the selected item, and cancellation from a submenu.

Native checks established that window movement beneath a stationary pointer
preserves selection; an unchanged pointer cannot undo a keyboard step; a held
stick and its release cannot erase pointer selection; and a click activates
the clicked item even when another item is highlighted. A mixed-input submenu
interaction returned Violet exactly once. Escape from a submenu returned a
single cancellation and hid the panel, rather than returning to the parent.
The final native run followed the adapter change that ignores pointer-enter
notifications, which can be generated by window movement alone.

The physical recording contains four successful GuliKit interactions:

- Sessions 2 and 4 recorded pointer selection of Blue, left-stick selection
  of Red, and physical confirmation producing exactly one selected Red result.
- Sessions 3 and 5 recorded pointer selection of Blue, native frame changes
  driven by the right stick, neutral release, and physical confirmation
  producing exactly one selected Blue result. Every recorded transition from
  movement through confirmation retained Blue as the pointer's selection.

The user confirmed that the first requested test chose Red and the second kept
Blue selected. This manual observation agrees with the recorded selections and
completed results.

An assertion probe checked those sequences, controller identity, bounds, and
the completed results. No pointer-movement events were recorded during the
movement portions. The app does not globally monitor mouse input outside its
own event stream; absence of an event is not a global mouse-motion measurement.
The physical recording predates the final change to ignore pointer-enter
notifications. The final native checks cover the resulting adapter.

Artifacts are saved locally under `build/verification/pointer/`: the native
report and structured events, physical recording and assertion results, unit
test output, and mutation source and results. They are excluded from Git.
VoiceOver usability, physical disconnect/reconnect behavior during an active
interaction, multiple physical controllers, display removal, and Spaces remain
outside these results. No latency or usability measurement is claimed.

## Movement milestone: 2026-09-23

On macOS 27.0 (26A428), with Xcode 27.0 and Swift 6.4 on Apple silicon:

- **45 XCTest tests passed:** 10 lifecycle, 10 controller interpretation,
  5 geometry/validation, 14 movement, 5 runtime, and 1 native operation-order
  test.
- **Three Python recording-verifier tests passed.** Negative cases remove or
  contradict physical input, displacement, neutral release, confirmation,
  bounds, and dismissal evidence.
- **14 native smoke checks passed.** These include the original lifecycle
  checks and movement using the real scheduler and AppKit window. Direct
  observations of the window frame established displacement and clamping.
  Neutral release, stale ticks, obsolete movement operations, and movement
  commands from a parent menu could not move the current menu afterward.
- **Two deliberately broken core variants failed the intended assertions.**
  Replacing elapsed time with a fixed step failed the rate-comparison test.
  Removing clock-identity validation failed the stale-tick test. Each variant
  compiled; the failures came from test assertions. Mutations ran in temporary
  copies, leaving the working implementation unchanged.

The deterministic timing tests compare 30, 60, and 120 ticks per second and
irregular intervals against explicit displacement values. They also check
velocity changes, separate device/receipt clocks, a capped long pause,
screen changes, pending acknowledgments, and actual-frame corrections. These
tests do not measure native timer precision or controller latency.

The **physical movement-to-confirmation check passed** with the connected
GuliKit Controller XW. Recorded session 2 contains physical right-stick input,
129 observed frame changes within screen bounds, neutral release with movement
stopped, and a Confirm press while Red remained selected. After native dismissal,
the app returned to Idle and emitted exactly one selected result for `red` in
the root menu. The recording verifier accepted this complete interaction.

The user identified the successful Confirm button as the bottom face button
labeled B. The right face button labeled A produced Back in the preceding
attempt. The adapter maps macOS `GCInputButtonA` to Confirm and
`GCInputButtonB` to Back; these names differ from the printed labels on the
tested controller. The controls documentation now states the observed mapping.

Earlier attempts ended with focus-loss cancellation or user cancellation.
The user-cancelled attempt independently confirmed movement to the screen edge
and a stationary frame for 8.2 seconds after the final right-stick release.
Red remained highlighted at dismissal, but no selected result was emitted.
The verifier rejected both incomplete attempts; visible dismissal alone was
insufficient evidence of confirmation.

The recording verifier also rejected the native smoke-test recording when
asked for GuliKit evidence: scripted movement was not mistaken for physical
input, even though the real controller was connected during that run.

Artifacts are saved locally under `build/verification/movement/`, including
the native report, structured events, test output, mutation results, and
physical recordings. `physical-confirmed.jsonl` contains the successful
interaction, and `physical-confirmed-result.json` contains its verifier result.
These artifacts are excluded from Git. The current recording format is
newline-delimited JSON; the older baseline recording below used plain text.

Markdown lint and whitespace checks passed for the changed documentation and
code. Physical disconnects, multiple physical controllers, screen removal,
Spaces, VoiceOver, and competing applications' controller delivery remain
unverified. Simulated tests and scripted native inputs do not replace those
observations.

## Initial prototype: 2026-09-22

The following records the preceding milestone on the same macOS/toolchain
versions.

### Automated results

`swift test --package-path prototype` passed 30 XCTest tests:

| Area | Tests | Result |
| --- | --- | --- |
| Core interaction lifecycle | 10 | Passed |
| Controller interpretation | 10 | Passed |
| Geometry and menu validation | 5 | Passed |
| Runtime ordering and resource ownership | 4 | Passed |
| Native operation ordering | 1 | Passed |

The bounded interaction test visited 9,331 prefixes of a six-event alphabet,
through depth five. This is bounded exploration, not an exhaustive proof of
the complete state space.

`./prototype/scripts/smoke-test.sh` passed nine checks against a real AppKit
panel and SwiftUI hosting view:

1. The root panel was visible and key after content acknowledgment.
2. An app-local native right-arrow event selected the first item.
3. Return produced the selected result after dismissal.
4. Completion left no visible panel.
5. The previously active application regained focus.
6. An obsolete native dismissal could not hide a newer session.
7. Submenu navigation retained the session and changed its input scope.
8. Explicit submenu activation returned the expected item identity.
9. Escape cancelled exactly one interaction.

The root, selected-root, and submenu renderings were inspected. The selected
item was visibly highlighted, the center control was distinct, and the fixed
example labels were readable. This was rendering inspection, not a measured
contrast or accessibility audit.

The final native report, renderings, event log, and unit-test output are saved
locally in `build/verification/`, which is excluded from Git. Rerunning the
smoke-test script produces a new temporary directory and prints its location.

### Physical controller evidence

The native adapter discovered the connected device as **GuliKit Controller
XW**. Its input inventory contained the required left stick, A Button,
B Button, and Menu button.

The user reported that both the root-item choice and submenu-item choice
worked in the requested physical test. This is manual test evidence. The
separate recording captured real Menu and stick input and cancellation
results, but did not contain matching successful-selection traces for those
two reported choices. The manual report is therefore not presented as a
captured end-to-end trace.

### Findings retained in tests and probes

Native testing found that an accessory application's cooperative activation
request did not make the panel key on this setup. Explicit activation fixed
that observed case. The adapter still requires visible/key observations and
can report timeout rather than assume activation succeeded.

Focus restoration initially timed out because the foreground-application
property was stale inside an activation callback. Reading the application
identity carried by the notification fixed the observed failure. The native
smoke test exercises the resulting focus handoff.

Controller tests caught a missed Menu cancellation before the first input
baseline and acceptance of a regressing input timestamp. Geometry tests
caught rounding into the preceding sector at exact boundaries. These cases
now have regression tests.

The standalone `Probes/LegacyControllerSnapshot.swift` experiment produced:

```text
Legacy A pressed: Optional(true)
Buffered A pressed: nil
Legacy stick x: Optional(0.5)
Buffered stick x: nil
```

That SDK facility cannot supply the assumed buffered-input fixture on this
setup. The unsuccessful fixture was not retained as an adapter test. Physical
input decoding consequently relies on native observation and manual testing;
the pure interpretation tests use explicit value fixtures.

### Other checks and limits

The new documentation and `ARCHITECTURE.md` pass Markdown lint. The root
README retains 32 existing formatting violations outside the new introduction
and prototype links. Shell syntax, the app property list, and whitespace
checks passed.

Desktop UI automation was unavailable because Computer Use permission was
not granted. VoiceOver usability, physical disconnection, multiple physical
controllers, screen removal, Spaces, and competing applications' controller
handling were not verified. Simulated disconnection and ownership tests do
not establish those native behaviors. No performance result is claimed.
