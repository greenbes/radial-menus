# Selectable menu styles

Use the **Menu style** dropdown in the diagnostics window. **Selected
message** shows short labels arranged around a ring, with a full title and
description in the center. **Pie wedges** shows the same short labels inside
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

Controller direction and keyboard order are identical in both styles. The
pointer targets visible sectors in Pie wedges and discrete label buttons in
Selected message. Moving off a target clears only pointer-owned selection.
The guide circle and explanatory text do not activate items. Back and Cancel
are separate controls. Accessibility exposes the full title and description
for either style.

Before display, the native boundary measures normal and selected labels,
including padding and submenu indicators. For Selected message it also measures
every complete message and the neutral instructions at a common width. The core
requires one measurement per item and one for the neutral state, then reserves
the largest required height. Labels, the window, and the navigation button
remain fixed while selection changes.

The geometry remains deterministic. Pie labels clear a circular center;
separate buttons clear a central rectangle and one another. Their angular order
is shared with controller selection. The window encloses all visible elements.
A layout that cannot fit at the requested text size fails explicitly before
accepting input. There is no automatic truncation or text-size reduction.

## Reproduce the checks

Quit the running prototype first, then use an unlocked macOS desktop:

```sh
./prototype/scripts/test.sh
./prototype/scripts/layout-test.sh
./prototype/scripts/layout-test.sh --selected-message
./prototype/scripts/smoke-test.sh
./prototype/scripts/smoke-test.sh --selected-message
./prototype/scripts/lifecycle-test.sh
```

The layout checks click both choices in the actual diagnostics window, reopen
menus with the chosen style, and exercise native Back and Cancel buttons. They
also check a style change during an interaction: the current submenu retains
its style and the next opening adopts the preference.

The selected-message matrix checks item counts 1 through 12, several label
profiles, submenus, and requested text sizes of 17 and 34 points. It measures
every central message, checks the displayed text through native accessibility
accessors, and verifies that the navigation control stays in place. Real
app-local mouse events check label selection, activation, and inert message
text. An injected 100-by-100 screen observation checks failure before display.

SwiftUI's accessibility nodes expose Objective-C accessors without declaring
the complete AppKit accessibility protocol. The native probe checks for those
accessors before reading them. It does not use private method names or represent
a VoiceOver session.

## Results and limits

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
