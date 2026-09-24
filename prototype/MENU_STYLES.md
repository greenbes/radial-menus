# Selectable menu styles

Use the **Menu style** dropdown in the diagnostics window. **Full labels**
implements design 1: complete titles in buttons around a compact ring, with
lines connecting the titles to markers at their controller directions.
Selection highlights the title button, connection, and marker, and shows a
checkmark. **Selected message** shows short labels arranged around a ring, with
a full title and description in the center. **Pie wedges** shows short labels inside
sectors. The default demo uses Selected message and six illustrative workspace
actions. Selecting an action reports its value; it does not perform the
described operation.

A style change applies to the next opening. An active interaction, including
its submenus, retains its original style. The preference remains in memory
until quitting. The prototype does not persist settings between launches.

## Content and behavior

An immutable item supplies its short label, full title, optional description,
and destination. When no distinct title is supplied, the label is also its
title. Definitions currently limit labels to 24 characters, titles to 160,
and descriptions to 600. These are input limits; native measurements determine
whether a particular menu fits the screen.

Controller direction and keyboard order are identical in all styles. The
pointer targets visible sectors in Pie wedges and discrete label buttons in
Full labels and Selected message. Moving off a target clears only pointer-owned
selection. Rings, markers, connections, and explanatory text do not activate
items. Back and Cancel
are separate controls. Accessibility exposes the full title and description
for every style. Full labels displays titles; descriptions appear visually
when using Selected message.

Before display, the native boundary measures normal and selected labels,
including padding and submenu indicators. For Selected message it also measures
every complete message and the neutral instructions at a common width. The core
requires one measurement per item and one for the neutral state, then reserves
the largest required height. Labels, the window, and the navigation button
remain fixed while selection changes.

The geometry remains deterministic. Pie labels clear a circular center;
Full labels clears a compact ring; Selected message clears a central rectangle.
Labels remain within their directional sectors and clear one another. Full-label
connections end at the inward edge of each label and cannot cross another label.
Their angular order
is shared with controller selection. The window encloses all visible elements.
A layout that cannot fit at the requested text size fails explicitly before
accepting input. There is no automatic truncation or text-size reduction.

## Reproduce the checks

Quit the running prototype first, then use an unlocked macOS desktop:

```sh
./prototype/scripts/test.sh
./prototype/scripts/layout-test.sh
./prototype/scripts/layout-test.sh --selected-message
./prototype/scripts/layout-test.sh --full-labels
./prototype/scripts/smoke-test.sh
./prototype/scripts/smoke-test.sh --selected-message
./prototype/scripts/smoke-test.sh --full-labels
./prototype/scripts/lifecycle-test.sh
```

The layout checks click all three choices in the actual diagnostics window, reopen
menus with the chosen style, and exercise native Back and Cancel buttons. They
also check a style change during an interaction: the current submenu retains
its style and the next opening adopts the preference.

The selected-message matrix checks item counts 1 through 12, several label
profiles, submenus, and requested text sizes of 17 and 34 points. It measures
every central message, checks the displayed text through native accessibility
accessors, and verifies that the navigation control stays in place. Real
app-local mouse events check label selection, activation, and inert message
text. An injected 100-by-100 screen observation checks failure before display.

The full-label matrix adds the six-item rich demo at both text sizes and two
fixtures at the 160-character title limit, including CJK text. It reads native
button names derived from the visible titles, checks native button frames
against pointer targets, and traverses every item with the keyboard. Repeated
titles are valid; the probe distinguishes their buttons by name and position.
Full-label buttons do not override the accessible name with a separate string.
Normal and selected measurements must fit the reserved bounds. An independent
Python verifier checks marker directions, connection endpoints, and intersections
with other labels. Negative fixtures check that the verifier rejects missing
text evidence and malformed or crossing connections.

SwiftUI's accessibility nodes expose Objective-C accessors without declaring
the complete AppKit accessibility protocol. The native probe checks for those
accessors before reading them. It does not use private method names or represent
a VoiceOver session.

## Full-label validation

Evidence for this implementation is retained under
`build/verification/full-labels/`, with source snapshots, hashes, native reports,
renderings, and test logs. All three styles were checked on the same build.

| Check | Observed result |
| --- | --- |
| Swift tests | 101 passed: 92 core, 8 runtime, 1 native operation-order test |
| Python verifier tests | 21 passed, including malformed connections |
| Full-label layout matrix | 68 fixtures passed |
| Existing layout regressions | 64 pie and 66 selected-message fixtures passed |
| Native full-label observations | 500 display states checked |
| Native keyboard traversal | 1,264 steps across all three matrices |
| Native interaction regression | 35 checks passed per style |

The full-label demo occupies a 728-point square at 17-point text and a
1,364-point square at 34-point text on the observed screen. The maximum-title
fixtures also fit without reducing text size. All styles passed native dropdown,
Back, and Cancel clicks and rejected the injected undersized screen before
presentation. Clicking the direction marker did not activate an item.

![Full labels](build/verification/full-labels/full-labels/rich.png)

The full-label probe originally assumed that button text appeared as separate
accessibility text nodes and that names were unique. Native observations
disproved both assumptions. The final probe reads names that SwiftUI derives
from the visible titles and matches repeated names by position. Those failed
probe observations are retained separately.

These checks used scripted input; the native reports listed no connected
controllers. Physical GuliKit operation of this style remains a separate check.
The screenshots were inspected in the observed Aqua appearance. This run did
not repeat the separate shutdown-process matrix or establish VoiceOver
usability, other appearances, or other display scales.

## Earlier two-style validation

The recorded environment was macOS 27.0 with Xcode 27.0 and Swift 6.4 on Apple
silicon, using a logged-in desktop. See the artifact manifest for exact versions
and source hashes. Evidence is retained under
`build/verification/menu-styles/`; earlier layout evidence remains separate.
The dropdown update reran the 66 selected-message fixtures, including both
choices through native menu-item clicks. That report and updated renderings
are under `build/verification/menu-style-dropdown/`. The probe waits for the
popup to close before opening it again.

| Check | Observed result |
| --- | --- |
| Swift tests | 96 passed: 87 core, 8 runtime, 1 native operation-order test |
| Python verifier tests | 19 passed, including controlled invalid reports |
| Pie layout matrix | 64 fixtures passed |
| Selected-message layout matrix | 66 fixtures passed |
| Native keyboard traversal | 832 steps across both matrices |
| Native full-message text and stable controls | 488 message states checked |
| Native interaction regression | 35 checks passed for each style |
| Shutdown processes | 8 cases passed, including the expected timeout failure |

The matrices also passed native style-picker clicks, Back/Cancel clicks,
expanded-layout pointer activation, and rejection of an undersized screen.

![Menu](build/verification/menu-styles/messages/rich-documents.png)

![Dropdown](build/verification/menu-style-dropdown/style-picker.png)

During development, native measurements exposed unnecessary circular space
reservation around rectangular content. A larger-text fixture initially needed
1,412 points on a screen with 1,410 available. Reserving space from the actual
rectangles corrected that case. The six-item rich fixture also initially
required 1,456 points; its final square window uses 1,262 points without changing
text size. The failed preparation observations are retained with the evidence.

The native checks use scripted input; they do not establish physical operation
of the new layout on the GuliKit, VoiceOver usability, or contrast over every
background. Earlier physical controller results apply to the earlier prototype.
The current layouts were inspected in Aqua at the recorded backing scale.
Other display scales, appearances, and controller models remain separate checks.
