# Layout validation results

**The measured layout passes all 64 native fixtures.** It corrects the
truncation and overlap demonstrated by the original fixed layout. This report
records the new observations first and retains the failing baseline below.

## Measured layout: 2026-09-23

The native shell measures the same SwiftUI components that render each label,
including normal and selected weights, explicit line breaks, Unicode, and
submenu indicators. It also measures the center control. The core receives
immutable sizes and the usable screen rectangle before requesting presentation.

The layout reserves each label's maximum measured width and height. It moves
label centers outward until every rectangle fits its sector and clears the
center control. The outer circle then encloses all rectangles with padding.
The computed window size includes a margin around that circle and is rounded
up to whole logical points. Drawing, pointer hit testing, and native placement
consume that layout; no separate fixed ring dimensions remain in those paths.

The default 17-point text uses a 96-point wrapping width. At 34 points, the
default width is 192 points. The wider proposal avoids the excessive word
splitting observed in an intermediate large-text rendering at the original
width. Text is never reduced to force a menu onto a screen.

| Label profile | Fixtures | Passed |
| --- | ---: | ---: |
| Short color names, counts 1–12 | 12 | 12 |
| Multiword labels, counts 1–12 | 12 | 12 |
| 24 wide Latin characters, counts 1–12 | 12 | 12 |
| Four explicit lines, counts 1–12 | 12 | 12 |
| CJK and mixed Unicode, counts 1–12 | 12 | 12 |
| Parent menu and twelve-item submenu | 2 | 2 |
| 34-point text: four multiword and two Unicode items | 2 | 2 |
| Total | 64 | 64 |

The Python verifier checks each fixture's measured content against the bounds
reserved by the core, then checks the inner and outer circles, sector boundaries,
label overlap, center control, requested text size, and actual panel/screen
bounds. Its geometry calculations are separate from the Swift implementation.
These conservative rectangle checks complement visual inspection; they do not
measure individual glyph pixels.

Native Right Arrow events traversed all 410 expected item identities. Return
opened the submenu and completed 63 interactions with the expected values.
A further native mouse sequence hovered and clicked the first item in the
twelve-item wide-text fixture at a radius of approximately 282 points, beyond
the former 150-point outer boundary. It returned the expected item exactly once.

A controlled test substituted a 100-by-100-point screen observation after real
native text measurement. The interaction reported a layout failure only after
cleanup, with no presentation request, visible panel, or selected result. Final
resource release succeeded. This is injected screen evidence, not a physical
display-change test.

The core tests cover all item counts with short, wide, and tall measured
rectangles, both font weights, reordered identities, large center content,
invalid/missing/overflowing values, negative desktop coordinates, insufficient
space, and enlarged hit regions. Preparation tests cover operation and session
identity, navigation, cancellation, shutdown, timeout, and late replies.

Three mutation probes compiled before failing the intended assertions:
removing sector containment, replacing measured hit testing with the old fixed
radius, and accepting measurement replies after cancellation or shutdown.
The unmodified temporary control passed. These probes establish that the
specific defects are detected; they are not exhaustive correctness evidence.

The full run also passed 87 Swift tests, 18 Python tests, 35 native interaction
assertions, and eight separate shutdown processes. The added shutdown case
withheld preparation's reply and observed a clean quit without showing a menu.

One final smoke run lost native focus during movement and cancelled with
`focusLost`, then timed out waiting for the screen edge. Its recording is
retained. A subsequent run of the same build passed all 35 checks. The trace
establishes focus loss; it does not identify what caused the focus change.

## Visual inspection and limits

Representative native images were inspected for wide text, explicit line
breaks, dense short and multiword menus, CJK and mixed Unicode, the submenu
indicator, the twelve-item child menu, and both enlarged-text fixtures. They
show full labels and clear separation from neighboring labels and controls.

The environment was macOS 27.0 (26A428), Aqua appearance, and reported backing
scale 1. The final matrix used the usable screen rectangle
`(-2560, 0, 2560, 1410)`. Native capture covers the hosted content view, not
compositor shadows. All cases used a responsive main thread; cooperative
operation deadlines do not interrupt a blocked native call.

This establishes layout behavior for the recorded fixtures and text sizes.
It does not establish VoiceOver announcements or focus behavior, physical
screen removal, other display scales or appearances, OS accessibility text
preferences, contrast compliance, or general usability. No new physical
controller result or performance benchmark is claimed.

## Baseline environment

These observations were recorded on 2026-09-23, on macOS 27.0 (26A428), using
the Aqua appearance and a reported backing scale of 1. The probe observed
usable screen rectangles `(-2560, 0, 2560, 1410)` and
`(0, 0, 2560, 1410)`. Other appearance, text-size, and display-scale settings
were not tested.

## Original fixed-layout baseline

The probe presented every item count from one through twelve, using five
label profiles. It also opened a parent menu and its twelve-item submenu.
All 62 presentations became active and produced native content-view images.

| Label profile | Fixtures | Satisfied layout checks |
| --- | ---: | ---: |
| Short color names | 12 | 9: item counts 1 through 9 |
| Multiword labels | 12 | 3: item counts 1, 2, and 4 |
| 24 wide Latin characters | 12 | 0 |
| Four explicit text lines | 12 | 0 |
| CJK and mixed Unicode labels | 12 | 0 |
| Parent menu and submenu | 2 | 0 |
| Total | 62 | 12 |

**50 fixtures failed the measured layout constraints.** These checks use
conservative text rectangles, including space needed for either font weight.
They do not mean that 50 images were individually judged unreadable. A
rectangle can cross a boundary while the glyphs leave that corner empty.
For example, the three-item multiword fixture looks readable but does not
satisfy the rectangle-containment check. The images described below establish
actual visible failures independently of that conservative criterion.

All panel frames fitted their observed usable screen bounds. All 404 native
Right Arrow events reached the expected item identities. Return entered the
submenu and completed the 61 interactions with the expected selected values.
Thus successful input routing and session completion did not establish
readable presentation.

## Visible failures in the baseline

### Text is truncated before the menu becomes dense

The one-item menu accepts a label containing 24 `W` characters. The measured
content requires 100 points of height at the current label width, but the view
allocates 60 points. Its native rendering ends in an ellipsis.

A four-line label requires 80 points and is also truncated. The CJK fixture
shows the same visible truncation. Character count does not bound text height
or width reliably.

### The submenu indicator reduces available label space

The two-item parent fixture contains `Open recent documents` with a submenu
indicator. Its complete label component requires 75 points of height. The
60-point box displays a truncated label even though there are only two items.

### Dense menus draw labels across neighboring sectors

In the twelve-item multiword fixture, labels visibly overlap neighboring
labels and cross sector borders. The twelve-item submenu has the same defect.
The twelve-item short-label image also shows `Orange` crossing its sector's
border. A fixed label position cannot provide enough space for every accepted
combination of item count and text.

## Baseline method and limits

Rendering and measurement share `MenuItemLabel`, including the actual SwiftUI
font, selected weight, line spacing, and submenu indicator. The native probe
uses `NSHostingController.sizeThatFits` at the production width to measure the
complete content without the production height constraint. It records normal
and selected measurements separately and reserves their maximum dimensions.

The Python verifier independently checks the resulting rectangles at the
renderer’s configured positions. It checks the label box, inner and outer
circles, sector boundaries, overlap, and observed panel/screen bounds. It also
rejects missing fixtures, invalid measurements, and incomplete keyboard checks.
The rectangles are calculated from native measurements and rendering parameters;
they are not measurements of individual glyph pixels in the final image.

Representative native images were inspected for the color fixture, dense
short and multiword menus, wide Latin text, explicit line breaks, CJK text,
and parent/child menus. Image capture covers the hosted content view; it does
not establish behavior of compositor shadows or other applications.

The validation additions passed all 74 Swift regression tests, all 17 Python
verifier tests, and the existing 35 native menu checks. Seven new verifier
tests include controlled cases for text overflow, overlap, incorrect sector
containment, inner-circle intersection, invalid data, and missing evidence.
The layout command itself returns failure for the defects above.

VoiceOver announcements, accessibility focus behavior, larger text settings,
and reduced-motion or increased-contrast preferences were not tested. Keyboard
success does not establish those behaviors.

## Reproduction and artifacts

Quit the normal prototype and run this from an unlocked desktop:

```sh
./prototype/scripts/layout-test.sh
```

The command builds the app, displays the fixtures, checks keyboard routing,
captures images, and writes `report.json` and `analysis.json` into the temporary
directory it prints. The command returns success only when all current fixtures
pass. A missing native report or incomplete keyboard sequence fails.

The original baseline, images, analysis, regression logs, and verifier source
remain under `build/verification/layout/`. The measured-layout matrix and
regression evidence are under `build/verification/measured-layout/`.
These generated artifacts are excluded from Git. The probe, fixtures, and
verifier are source files and can reproduce the checks on another Mac.
