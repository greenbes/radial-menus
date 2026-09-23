# Prototype validation

These results apply to the fixed example menu and the recorded environment;
they do not establish support for every device or desktop setup.

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
