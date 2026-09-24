# Selectable menu styles

Use the **Menu style** dropdown in the diagnostics window. **Full labels**
implements design 1: complete titles in buttons around a compact ring, with
lines connecting the titles to markers at their controller directions. Selection
highlights the title button, connection, and marker, and shows a checkmark.
**Full labels with icons** replaces the direction markers with action icons,
removes connecting lines, and leaves the center empty. Selection fills the icon
badge and title button with the same accent color and adds a three-point white
outline inside their bounds. There is no selection checkmark; submenu arrows
remain visible. **Cards** implements design
2: titles and descriptions are visible together in radial cards. Selection adds
a light tint, an accent outline, and a checkmark. **Selected message** shows
short labels arranged around a ring, with a full title and description in the
center. **Pie wedges** shows short labels inside sectors. The default demo uses
Selected message and six illustrative workspace actions. Selecting an action
reports its value; it does not perform the described operation.

A style change applies to the next opening. An active interaction, including
its submenus, retains its original style. The preference remains in memory
until quitting. The prototype does not persist settings between launches.

## Content and behavior

An immutable item supplies its short label, full title, optional description, a
semantic built-in icon, and destination. The view layer maps icons to SF
Symbols; unspecified leaf items use a dotted circle and submenus use a grid.
When no distinct title is supplied, the label is also its title. Definitions
currently limit labels to 24 characters, titles to 160, and descriptions to 600.
These are input limits; native measurements determine whether a particular menu
fits the screen.

Controller direction and keyboard order are identical in all styles. The pointer
targets visible sectors in Pie wedges and discrete label buttons in Full labels,
Full labels with icons, Cards, and Selected message. Moving off a target clears
only pointer-owned selection. Rings, markers, connections, and central message
text do not activate items. A card's description is part of its item button, so
clicking it chooses that item. Back and Cancel are separate controls except in
Full labels with icons. That style uses controller Back, keyboard Delete, or a
named accessibility action to go back or cancel at the root. Escape cancels the
whole interaction. Clicking its empty center or icons has no effect.
Accessibility exposes the full title and description for every style. Full
labels displays titles; descriptions appear visually when using Cards or
Selected message.

Before display, the native boundary measures normal and selected labels,
including padding and submenu indicators. For Selected message it also measures
every complete message and the neutral instructions at a common width. The core
requires one measurement per item and one for the neutral state, then reserves
the largest required height. Item bounds, the window, and the navigation button
remain fixed while selection changes.

The geometry remains deterministic. Pie labels clear a circular center; both
full-label styles and Cards clear a compact ring; Selected message clears a
central rectangle. Both full-label styles and Selected message stay within their
sectors. Cards can extend across sector boundaries, but remain disjoint and
cannot obscure another item's connection. Their centers retain the same
controller directions. Full-label connections end at the inward edge of each
label and cannot cross another label. Their angular order is shared with
controller selection. The window encloses all visible elements. A layout that
cannot fit at the requested text size fails explicitly before accepting input.
There is no automatic truncation or text-size reduction.

## Reproduce the checks

Quit the running prototype first, then use an unlocked macOS desktop:

```sh
./prototype/scripts/test.sh
./prototype/scripts/layout-test.sh
./prototype/scripts/layout-test.sh --selected-message
./prototype/scripts/layout-test.sh --full-labels
./prototype/scripts/layout-test.sh --icon-labels
./prototype/scripts/layout-test.sh --cards
./prototype/scripts/smoke-test.sh
./prototype/scripts/smoke-test.sh --selected-message
./prototype/scripts/smoke-test.sh --full-labels
./prototype/scripts/smoke-test.sh --icon-labels
./prototype/scripts/smoke-test.sh --cards
./prototype/scripts/lifecycle-test.sh
```

The layout checks click all five choices in the actual diagnostics window,
reopen menus with the chosen style, and exercise native Back and Cancel buttons
(Delete and Escape for Full labels with icons). They also check a style change
during an interaction: the current submenu retains its style and the next
opening adopts the preference.

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

## Icon-label validation

Run `./prototype/scripts/run.sh --icon-labels` to select this style. Before
presentation, the native boundary measures each symbol at normal and selected
weights. The core encloses the glyphs in badges with padding and separates
adjacent badges for every supported item count. Labels retain their full-title
measurements and controller directions. No center control is measured or
rendered, and no connection geometry is supplied.

The native probe records rendered pixels in each icon badge and its label, at
the center, and in the gap where a connecting line would appear. The independent
verifier requires matching opaque icon and label colors, exactly one highlight
for the selected item, and transparent center and gap pixels. It also checks
native glyph sizes, badge separation, item directions, full title button bounds,
and stable placement through every selection. Controlled invalid reports
exercise missing highlights, mismatched colors, visible lines or center content,
incorrect directions, and oversized glyphs.

The menu supplies explicit accessibility children from the same control views
used for display. This keeps decorative geometry out of the button frames,
including when there is only one item. Native accessibility actions exercise
submenu activation, Back, Cancel, and choosing an item when another is selected.
These checks invoke the real native actions; they do not establish VoiceOver
usability.

The selection outline update removes the checkmark and its reserved space from
leaf items. Submenu arrows stay visible in both selection states. Selected
labels and icon badges have a three-point white outline drawn inside their
existing bounds. A separate native pixel probe measures the contrasting border
on both shapes and checks that unselected labels keep their thin border.

The update passed 109 Swift tests, 26 Python verifier tests, 68 native layout
cases with 500 selection states, and 68 independent outline pixel checks.
Interaction smoke tests passed 35 checks each for the icon-label and original
full-label styles. The connected GuliKit was detected; these checks used
scripted input and do not establish physical controller usability.

Current selection renderings and probe results are retained under
`build/verification/icon-selection-outline/`. The original icon-style validation
below remains under `build/verification/icon-labels/`.

![Selection outline](build/verification/icon-selection-outline/layout/rich.png)

### Initial icon-style validation

| Check | Observed result |
| --- | --- |
| Swift tests | 109 passed: 100 core, 8 runtime, 1 native operation-order test |
| Python verifier tests | 26 passed, including invalid icon reports |
| Icon-label layout matrix | 68 fixtures and 500 selection states passed |
| Existing style layout regressions | 279 fixtures passed across four styles |
| Native keyboard traversal | 2,208 steps across all five matrices |
| Native interaction smoke tests | 35 checks passed per style |
| Native accessibility actions | Submenu, Back, Cancel, activation passed |

The six-item demo occupies a 728-point square at 17-point text and a
1,364-point square at 34 points on the observed screen. Visual inspection
covered the dropdown, this demo at both sizes, and the twelve-item wide-label
fixture in Aqua. The measurements do not establish fit on every screen.
Physical controller operation, a VoiceOver session, and other appearances
remain separate checks. The smoke reports list no connected controllers.

Evidence is retained in `build/verification/icon-labels/`, including native
reports, renderings, test logs, and source snapshots. A diagnostic run with the
ring removed failed all 68 pixel checks. The earlier single-item
accessibility-frame failure is retained separately.

![Full labels with icons](build/verification/icon-labels/icon-labels/rich.png)

## Card validation

| Check | Observed result |
| --- | --- |
| Swift tests | 105 passed: 96 core, 8 runtime, 1 native operation-order test |
| Python verifier tests | 21 passed |
| Native layout matrices | 279 fixtures across all four styles passed |
| Card text, bounds, and central control | 593 display states checked |
| Native keyboard traversal | 1,776 steps across all four matrices |
| Native interaction regression | 35 checks passed per style |
| Deliberate geometry faults | Both rejected; unmodified control passed |

The card matrix contains 81 fixtures: the full-label cases plus descriptions
at every supported item count and a fixture with 600-character descriptions.
It checks 593 display states for complete native text, button bounds, and a
fixed central control. The description is part of the card's accessible name,
derived from visible text rather than supplied separately. A native click in
the description area must activate that card even when another item is selected.

Cards reserve the greater normal or selected height before display. Empty
descriptions add no description row. The requested text size stays fixed;
there is no ellipsis or automatic size reduction. The native width probe
compared seven widths at 17 and 34 points. The chosen width is 210 points at
17-point text and scales with the requested size. The rich demo occupies a
739-point square at 17 points and a 1,391-point square at 34 points on the
observed screen. The 600-character description fixture occupies 1,370 points.
These measurements do not imply that every allowed menu fits every screen.

The pure spacing calculation separates each pair of card rectangles. It also
keeps each rectangle clear of the segment from the center to any other card's
center; the visible connection is shorter than that segment. A card may extend
across an angular boundary, so its connecting line indicates its controller
direction. The independent verifier clips each visible line against the other
card rectangles. Two deliberate faults remove rectangle separation and line
separation separately; both are rejected by the geometry tests. The unmodified
control passes. A wide card beside a small card specifically exercises an
obscured connection that rectangle overlap checks alone would miss.

Native text measurement initially exposed excessive space reserved by the
sector rule and an unsuitable width at larger text sizes. Failed preparation
observations, the width probe, and the final reports are retained under
`build/verification/cards/`, along with source snapshots and hashes.

![Cards](build/verification/cards/cards/rich.png)

The checks use scripted input and do not establish physical controller or
VoiceOver usability. The native reports list no connected controllers. Visual
inspection covers the observed Aqua appearance; other appearances and scales
remain separate checks. The shutdown-process matrix was not repeated for this
presentation change.

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
