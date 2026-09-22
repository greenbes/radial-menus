# Prototype validation

Observed on 2026-09-22 using macOS 27.0 (26A428), Xcode 27.0, Swift 6.4,
and an Apple silicon Mac. These results apply to this prototype and its fixed
example menu; they do not establish support for every device or desktop setup.

## Automated results

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

## Physical controller evidence

The native adapter discovered the connected device as **GuliKit Controller
XW**. Its input inventory contained the required left stick, A Button,
B Button, and Menu button.

The user reported that both the root-item choice and submenu-item choice
worked in the requested physical test. This is manual test evidence. The
separate recording captured real Menu and stick input and cancellation
results, but did not contain matching successful-selection traces for those
two reported choices. The manual report is therefore not presented as a
captured end-to-end trace.

## Findings retained in tests and probes

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

## Other checks and limits

The new documentation and `ARCHITECTURE.md` pass Markdown lint. The root
README retains 32 existing formatting violations outside the new introduction
and prototype links. Shell syntax, the app property list, and whitespace
checks passed.

Desktop UI automation was unavailable because Computer Use permission was
not granted. VoiceOver usability, physical disconnection, multiple physical
controllers, screen removal, Spaces, and competing applications' controller
handling were not verified. Simulated disconnection and ownership tests do
not establish those native behaviors. No performance result is claimed.
