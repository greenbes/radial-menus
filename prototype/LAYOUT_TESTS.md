# Layout validation

The definition validator accepts one through twelve items and labels containing
up to 24 characters. Those limits do not establish that text fits on screen.
Validate native rendering before treating an accepted definition as presentable.

## Expected behavior

- Show every label in full at the requested text size, including the selected
  font weight and submenu indicator. Do not truncate or shrink text to fit.
- Keep each label inside its own selectable sector, outside the center control,
  and clear of other labels. Keep the complete menu inside the usable screen.
- Use the same geometry for drawing, pointer selection, and controller direction.
- Preserve item identity through keyboard selection, clicking, and nested menus.
- Report a layout failure when the required content cannot fit. Do not make an
  unusable menu active or return a selected result for it.

## Fixtures and observations

Exercise every item count from one through twelve. Include short words,
multiword labels, 24 wide characters, explicit line breaks, Unicode, and nested
menus. Include larger text with its corresponding wrapping width and center
control.
Measure the real SwiftUI label at both normal and selected weight. Capture
the actual AppKit panel and inspect the images for clipping and overlap.

Use deterministic geometry tests for measured rectangles and screen limits.
Use native probes for text measurement and rendering; character counts are
not a substitute for font measurement. Record baseline failures as evidence,
then rerun the same fixtures after any correction.

Use the rectangle containing both normal and selected font measurements as
a conservative layout requirement. Distinguish rectangle overlap from visible
glyph overlap when reporting results; inspect native images independently.

Use native pointer movement and clicking in an expanded ring, outside the old
150-point radius. Inject an undersized screen observation to establish failure
before presentation and resource cleanup. Label the injection explicitly; it
does not establish physical monitor-removal behavior.

The probe must also receive actual keyboard steps for all items, open the
nested menu with Return, and confirm the expected result for each interaction.

Keyboard and accessibility activation checks establish event routing only.
VoiceOver announcements and usability require separate native observation;
an accessibility label in source code is not sufficient evidence.
