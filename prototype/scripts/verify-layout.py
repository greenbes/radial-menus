"""Validate native text measurements against the displayed radial layout."""

import argparse
import itertools
import json
import math
from pathlib import Path

EPSILON = 1e-6
PROFILES = ("short", "long", "wide", "multiline", "unicode")


def numbers(value, count):
    if (not isinstance(value, list) or len(value) != count or
            any(isinstance(v, bool) or not isinstance(v, (float, int)) or not math.isfinite(v) for v in value)):
        raise ValueError("Missing or invalid numeric observations")
    return value


def contained(inner, outer):
    x, y, width, height = inner
    ox, oy, ow, oh = outer
    return (x >= ox - EPSILON and y >= oy - EPSILON and
            x + width <= ox + ow + EPSILON and y + height <= oy + oh + EPSILON)


def segment_intersects_box(start, end, box):
    """Clip a finite line segment to the rectangle on each axis."""
    low, high = 0.0, 1.0
    for origin, destination, minimum, size in zip(start, end, box[:2], box[2:]):
        delta = destination - origin
        if abs(delta) < EPSILON:
            if origin < minimum or origin > minimum + size:
                return False
        else:
            a, b = sorted(((minimum - origin) / delta, (minimum + size - origin) / delta))
            low, high = max(low, a), min(high, b)
            if low > high:
                return False
    return True


def check_direction_guide(fixture):
    if any(fixture.get(key) is not True for key in
           ("stableSelectionLayout", "stableNavigationControl", "nativeFullTitleTextVerified", "nativeLabelFramesVerified")):
        raise ValueError("Missing native full-title or stable frame evidence")
    guide, geometry, labels = fixture["directionGuide"], fixture["geometry"], fixture["labels"]
    radius, marker_radius = numbers([guide["radius"], guide["markerRadius"]], 2)
    if not 0 < marker_radius < radius or radius - marker_radius <= geometry["centerRadius"]:
        raise ValueError("Direction markers touch the central control")
    if radius + marker_radius > min(geometry["innerRadius"], geometry["diameter"] / 2):
        raise ValueError("Direction ring exceeds its reserved space")
    connections = guide["connections"]
    if [c["id"] for c in connections] != [label["id"] for label in labels]:
        raise ValueError("Missing, reordered or incorrect direction connections")
    issues = []
    for index, (connection, label) in enumerate(zip(connections, labels)):
        start, end = numbers(connection["marker"], 2), numbers(connection["labelEdge"], 2)
        angle = index * 2 * math.pi / len(labels)
        direction = math.sin(angle), -math.cos(angle)
        if any(abs(p - v * radius) > EPSILON for p, v in zip(start, direction)):
            issues.append({"kind": "markerHasWrongDirection", "item": label["id"]})
        x, y, width, height = label["rectangle"]
        on_edge = (x - EPSILON <= end[0] <= x + width + EPSILON and
                   y - EPSILON <= end[1] <= y + height + EPSILON and
                   min(abs(end[0] - x), abs(end[0] - x - width),
                       abs(end[1] - y), abs(end[1] - y - height)) < EPSILON)
        cross = end[0] * direction[1] - end[1] * direction[0]
        forward = sum(p * v for p, v in zip(end, direction))
        label_distance = (x + width / 2) * direction[0] + (y + height / 2) * direction[1]
        if not on_edge or abs(cross) > EPSILON or not radius + marker_radius < forward < label_distance:
            issues.append({"kind": "connectionMissesLabelEdge", "item": label["id"]})
        for other in labels:
            if other["id"] != label["id"] and segment_intersects_box(start, end, other["rectangle"]):
                issues.append({"kind": "connectionCrossesAnotherLabel", "item": label["id"]})
    return issues


def check_icon_ring(fixture):
    if any(fixture.get(key) is not True for key in
           ("stableSelectionLayout", "nativeFullTitleTextVerified", "nativeLabelFramesVerified")):
        raise ValueError("Missing native icon label or stable frame evidence")
    if fixture["directionGuide"] or fixture["centerBounds"] != [0, 0, 0, 0]:
        raise ValueError("Icon labels contain a center control or connecting lines")
    labels, geometry = fixture["labels"], fixture["geometry"]
    states = fixture["iconStates"]
    ids = [label["id"] for label in labels]
    if len(states) != len(ids) + 1 or {state["selectedID"] for state in states} != {None, *ids}:
        raise ValueError("Missing icon selection observations")
    issues = []
    original = None
    for state in states:
        radius, badge = numbers([state["radius"], state["badgeRadius"]], 2)
        if not 0 < badge < radius or radius + badge > min(geometry["innerRadius"], geometry["diameter"] / 2):
            raise ValueError("Icon ring exceeds its reserved space")
        if numbers(state["centerPixel"], 4)[3] != 0:
            issues.append({"kind": "centerIsNotEmpty"})
        icons = state["icons"]
        if [icon["id"] for icon in icons] != ids:
            raise ValueError("Missing or incorrect icon identities")
        positions = [numbers(icon["center"], 2) for icon in icons]
        if original is not None and original != (radius, badge, positions):
            raise ValueError("Selection moved the icon ring")
        original = radius, badge, positions
        for index, icon in enumerate(icons):
            angle = index * 2 * math.pi / len(ids)
            if any(abs(a - b) > EPSILON for a, b in zip(positions[index], (math.sin(angle) * radius, -math.cos(angle) * radius))):
                issues.append({"kind": "iconHasWrongDirection", "item": icon["id"]})
            for key in ("normal", "selected"):
                size = numbers(icon[key], 2)
                if min(size) <= 0 or math.hypot(*size) / 2 >= badge:
                    issues.append({"kind": "glyphExceedsBadge", "item": icon["id"]})
            fill, label = numbers(icon["iconFill"], 4), numbers(icon["labelFill"], 4)
            if min(fill[3], label[3]) < 0.99 or any(abs(a - b) > 0.02 for a, b in zip(fill, label)):
                issues.append({"kind": "iconAndLabelColorsDiffer", "item": icon["id"]})
            if numbers(icon["gapPixel"], 4)[3] != 0:
                issues.append({"kind": "connectingLineIsVisible", "item": icon["id"]})
        for a, b in itertools.combinations(positions, 2):
            if math.dist(a, b) <= 2 * badge:
                issues.append({"kind": "iconBadgesOverlap"})
    neutral = next(state for state in states if state["selectedID"] is None)
    for state in states:
        for base, icon in zip(neutral["icons"], state["icons"]):
            changed = any(abs(a - b) > 0.02 for a, b in zip(base["iconFill"], icon["iconFill"]))
            if changed != (icon["id"] == state["selectedID"]):
                issues.append({"kind": "wrongIconHighlighted", "item": icon["id"]})
    return issues


def check_floating_labels(fixture):
    if any(fixture.get(key) is not True for key in
           ("stableSelectionLayout", "nativeFullTitleTextVerified", "nativeLabelFramesVerified")):
        raise ValueError("Missing native floating label text or stable frame evidence")
    if fixture["directionGuide"] or fixture["iconStates"] or fixture["centerBounds"] != [0, 0, 0, 0]:
        raise ValueError("Floating labels contain a ring, line, or central control")
    labels, geometry = fixture["labels"], fixture["geometry"]
    issues = []
    for index, label in enumerate(labels):
        x, y, w, h = label["rectangle"]
        corner = numbers([label["cornerRadius"]], 1)[0]
        if not 0 < corner <= min(w, h) / 2:
            raise ValueError("Invalid rounded corner")
        # Project the origin onto the inset box, then onto its rounded boundary.
        qx, qy = min(max(0, x + corner), x + w - corner), min(max(0, y + corner), y + h - corner)
        distance = math.hypot(qx, qy)
        angle = index * 2 * math.pi / len(labels)
        if distance <= corner:
            issues.append({"kind": "labelTouchesCenter", "item": label["id"]})
        else:
            nearest = qx * (1 - corner / distance), qy * (1 - corner / distance)
            expected = math.sin(angle) * geometry["labelRadius"], -math.cos(angle) * geometry["labelRadius"]
            if math.dist(nearest, expected) > EPSILON:
                issues.append({"kind": "labelIsNotTangent", "item": label["id"]})
        if [w, h] != [math.ceil(v) for v in label["measured"]]:
            issues.append({"kind": "labelDoesNotFitIntrinsicSize", "item": label["id"]})
        lines, title = label["lines"], label["title"]
        if " ".join(lines).split() != title.split():
            issues.append({"kind": "wrappedTextChangedWords", "item": label["id"]})
        # Swift unit cases cover grapheme clusters; native checks also count
        # rendered lines with Foundation. ASCII provides a separate length oracle.
        if title.isascii():
            if any(len(line) > 20 and len(line.split()) != 1 for line in lines):
                issues.append({"kind": "lineExceedsCharacterLimit", "item": label["id"]})
            expected_lines = []
            for paragraph in title.split("\n"):
                current = ""
                for word in paragraph.split():
                    candidate = (current + " " + word).strip()
                    if current and len(candidate) > 20:
                        expected_lines.append(current)
                        current = word
                    else:
                        current = candidate
                expected_lines.append(current)
            if lines != expected_lines:
                issues.append({"kind": "incorrectWordWrapping", "item": label["id"]})
    ids = [label["id"] for label in labels]
    states = fixture["floatingStates"]
    if len(states) != len(ids) + 1 or {state["selectedID"] for state in states} != {None, *ids}:
        raise ValueError("Missing floating label selection observations")
    neutral = next(state for state in states if state["selectedID"] is None)
    for state in states:
        if state["centerAlpha"] != 0 or any(numbers(state["gapAlpha"], len(ids))):
            issues.append({"kind": "centerOrRingIsVisible"})
        if [label["id"] for label in state["labels"]] != ids:
            raise ValueError("Missing native label pixels")
        for base, label in zip(neutral["labels"], state["labels"]):
            fill, outline = numbers(label["fill"], 4), numbers(label["outline"], 4)
            changed = any(abs(a - b) > 0.02 for a, b in zip(base["fill"], fill))
            selected = label["id"] == state["selectedID"]
            if changed != selected or fill[3] < 0.99:
                issues.append({"kind": "wrongLabelHighlighted", "item": label["id"]})
            if selected and any(value < 0.98 for value in outline):
                issues.append({"kind": "missingThickSelectionOutline", "item": label["id"]})
    return issues


def check_fixture(fixture):
    issues = []
    geometry = fixture["geometry"]
    values = numbers([geometry[key] for key in
                      ("innerRadius", "outerRadius", "diameter", "labelRadius", "labelWidth", "fontSize", "centerRadius")], 7)
    if min(values[:3] + values[4:6]) <= 0 or not values[0] < values[1] or values[6] < 0:
        raise ValueError("Invalid recorded rendering parameters")
    if fixture.get("style", "pie") == "pie" and not values[6] < values[0] < values[1] <= values[2] / 2:
        raise ValueError("Invalid pie rendering parameters")
    if geometry["labelRadius"] > geometry["diameter"] / 2:
        raise ValueError("The guide circle exceeds the panel")
    center = numbers(fixture["centerMeasured"], 2)
    if fixture.get("style") in ("iconLabels", "floatingLabels"):
        if center != [0, 0] or values[6] != 0:
            raise ValueError("Icon labels must have an empty center")
    elif min(center) <= 0 or values[6] <= 0:
        raise ValueError("Invalid center measurement")
    if math.hypot(*center) / 2 > geometry["centerRadius"] + EPSILON:
        issues.append({"kind": "centerContentExceedsCircle"})
    count, labels = fixture["count"], fixture["labels"]
    if not 1 <= count <= 12 or len(labels) != count or len({x["id"] for x in labels}) != count:
        raise ValueError("Missing, repeated, or invalid item observations")
    if fixture["keyboardSteps"] != count:
        raise ValueError("Keyboard traversal did not reach every item")
    frame, screen = numbers(fixture["frame"], 4), numbers(fixture["screenBounds"], 4)
    if min(frame[2:] + screen[2:]) <= 0:
        raise ValueError("Invalid panel or screen size")
    if not contained(frame, screen):
        issues.append({"kind": "panelOutsideScreen"})
    window_size = numbers(geometry.get("windowSize", [geometry["diameter"]] * 2), 2)
    if min(window_size) <= 0 or max(window_size) != geometry["diameter"]:
        raise ValueError("Invalid window dimensions")
    if frame[2:] != window_size:
        issues.append({"kind": "unexpectedPanelSize"})
    if fixture.get("style", "pie") == "selectedMessage":
        if any(fixture.get(key) is not True for key in
               ("stableSelectionLayout", "stableNavigationControl", "nativeMessageTextVerified", "nativeLabelFramesVerified")):
            raise ValueError("Missing stable layout or native message text evidence")
        cx, cy, cw, ch = numbers(fixture["centerBounds"], 4)
        if min(cw, ch) <= 0 or cx != -cw / 2 or [cw, ch] != center:
            raise ValueError("Invalid central message bounds")
        radius = geometry["labelRadius"]
        if not radius / 3 - EPSILON <= cy + ch / 2 <= 2 * radius / 3 + EPSILON:
            issues.append({"kind": "messageOutsideLowerThird"})
        if not contained([cx, cy, cw, ch], [-window_size[0] / 2, -window_size[1] / 2, *window_size]):
            issues.append({"kind": "centerOutsidePanel"})
        back = fixture["messageBackBounds"]
        if (back is not None) != fixture["canGoBack"]:
            raise ValueError("Back control does not match menu depth")
        if back is not None:
            bx, by, bw, bh = numbers(back, 4)
            if min(bw, bh) <= 0 or bx != -bw / 2:
                raise ValueError("Invalid message Back control")
            if abs(by - cy - ch - geometry["fontSize"] * 0.65) > EPSILON:
                issues.append({"kind": "backNotBelowCard"})
        for box in [fixture["centerBounds"]] + ([back] if back is not None else []):
            x, y, w, h = box
            if any(math.hypot(xx, yy) > radius - 8 + EPSILON
                   for xx, yy in itertools.product((x, x + w), (y, y + h))):
                issues.append({"kind": "messageContentOutsideRing"})
        messages = fixture["messages"]
        expected = {None} | {label["id"] for label in labels}
        if len(messages) != len(expected) or {m["id"] for m in messages} != expected:
            raise ValueError("Missing or duplicated message measurements")
        for message in messages:
            actual_card = numbers(message["cardBounds"], 4)
            if any(abs(a - b) >= 1 for a, b in zip(actual_card, fixture["centerBounds"])):
                issues.append({"kind": "nativeCardPositionMismatch", "item": message["id"]})
            actual_back = message["backBounds"]
            if (actual_back is None) != (back is None):
                raise ValueError("Missing or unexpected native Back control")
            if back is not None and any(abs(a - b) >= 1 for a, b in zip(numbers(actual_back, 4), back)):
                issues.append({"kind": "nativeBackPositionMismatch", "item": message["id"]})
            w, h = numbers(message["measured"], 2)
            if min(w, h) <= 0:
                raise ValueError("Invalid message measurement")
            if w > cw + EPSILON or h > ch + EPSILON:
                issues.append({"kind": "messageExceedsCenter", "item": message["id"]})
    rectangles = []
    for index, label in enumerate(labels):
        width, height = numbers(label["measured"], 2)
        normal, selected = numbers(label["normal"], 2), numbers(label["selected"], 2)
        if min(normal + selected + [width, height]) <= 0:
            raise ValueError("Empty label measurement")
        if [width, height] != [max(normal[0], selected[0]), max(normal[1], selected[1])]:
            raise ValueError("Measurement does not contain both font weights")
        angle = index * 2 * math.pi / count
        rectangle = numbers(label["rectangle"], 4)
        x, y, reserved_width, reserved_height = rectangle
        expected_x = math.sin(angle) * geometry["labelRadius"] - reserved_width / 2
        expected_y = -math.cos(angle) * geometry["labelRadius"] - reserved_height / 2
        if min(reserved_width, reserved_height) <= 0 or (fixture.get("style") not in ("floatingLabels", "selectedMessage") and
                (abs(x - expected_x) > EPSILON or abs(y - expected_y) > EPSILON)):
            raise ValueError("Label position differs from recorded rendering parameters")
        rectangles.append(rectangle)
        kinds = []
        if width > reserved_width + EPSILON or height > reserved_height + EPSILON:
            kinds.append("contentExceedsLabelBox")
        d = geometry["diameter"]
        if not contained(rectangle, [-window_size[0] / 2, -window_size[1] / 2, *window_size]):
            kinds.append("labelOutsidePanel")
        width, height = reserved_width, reserved_height
        corners = list(itertools.product((x, x + width), (y, y + height)))
        if any(math.hypot(cx, cy) > geometry["outerRadius"] + EPSILON for cx, cy in corners):
            kinds.append("labelOutsideRing")
        closest_x, closest_y = min(max(0, x), x + width), min(max(0, y), y + height)
        if fixture.get("style", "pie") == "selectedMessage":
            corner = numbers([label["cornerRadius"]], 1)[0]
            if not 0 < corner <= min(width, height) / 2:
                raise ValueError("Invalid selected-message corner radius")
            qx = min(max(0, x + corner), x + width - corner)
            qy = min(max(0, y + corner), y + height - corner)
            distance = math.hypot(qx, qy)
            if distance <= corner:
                kinds.append("labelTouchesRingInterior")
            else:
                nearest = (qx * (1 - corner / distance), qy * (1 - corner / distance))
                expected = (math.sin(angle) * geometry["labelRadius"], -math.cos(angle) * geometry["labelRadius"])
                if math.dist(nearest, expected) > EPSILON:
                    kinds.append("labelIsNotTangent")
            cx, cy, cw, ch = fixture["centerBounds"]
            if min(x + width, cx + cw) - max(x, cx) > -EPSILON and min(y + height, cy + ch) - max(y, cy) > -EPSILON:
                kinds.append("labelTouchesCenter")
        elif fixture.get("style") != "floatingLabels" and math.hypot(closest_x, closest_y) <= geometry["innerRadius"] + EPSILON:
            kinds.append("labelTouchesCenter")
        if count > 1 and fixture.get("style") not in ("cards", "floatingLabels", "selectedMessage"):
            differences = [math.remainder(math.atan2(cx, -cy) - angle, 2 * math.pi) for cx, cy in corners]
            if any(abs(difference) > math.pi / count + EPSILON for difference in differences):
                kinds.append("labelOutsideOwnSector")
        for kind in kinds:
            issues.append({"kind": kind, "item": label["id"]})
    for a, b in itertools.combinations(range(count), 2):
        ax, ay, aw, ah = rectangles[a]
        bx, by, bw, bh = rectangles[b]
        if min(ax + aw, bx + bw) - max(ax, bx) > EPSILON and min(ay + ah, by + bh) - max(ay, by) > EPSILON:
            issues.append({"kind": "labelEnvelopesOverlap", "items": [labels[a]["id"], labels[b]["id"]]})
    if fixture.get("style") in ("fullLabels", "cards"):
        issues.extend(check_direction_guide(fixture))
    if fixture.get("style") == "cards" and fixture.get("nativeCardTextVerified") is not True:
        raise ValueError("Missing native card title and description evidence")
    if fixture.get("style") == "iconLabels":
        issues.extend(check_icon_ring(fixture))
    if fixture.get("style") == "floatingLabels":
        issues.extend(check_floating_labels(fixture))
    return issues


def verify(report):
    expected = {f"{count}-{profile}" for count in range(1, 13) for profile in PROFILES} | {"nested", "nested-child", "large-type-4-long", "large-type-2-unicode"}
    style = report.get("style", "pie")
    if style not in ("pie", "fullLabels", "iconLabels", "floatingLabels", "cards", "selectedMessage"):
        raise ValueError("Unknown menu style")
    if style != "pie":
        expected |= {"rich", "large-type-rich"}
    if style in ("fullLabels", "iconLabels", "floatingLabels", "cards"):
        expected |= {"6-full-title", "4-unicode-title"}
    if style == "floatingLabels":
        expected.add("6-variable-width")
    if style == "cards":
        expected |= {f"{count}-details" for count in range(1, 13)} | {"2-max-detail"}
    fixtures = report["fixtures"]
    if {f["name"] for f in fixtures} != expected or len(fixtures) != len(expected):
        raise ValueError("Missing or duplicate layout fixtures")
    for fixture in fixtures:
        name = fixture["name"]
        count = 6 if name in ("rich", "large-type-rich") else 2 if name == "nested" else 12 if name == "nested-child" else int(name.removeprefix("large-type-").split("-", 1)[0])
        if fixture.get("style", "pie") != style:
            raise ValueError("Fixture uses the wrong menu style")
        width = ({"pie": 96, "fullLabels": 226, "iconLabels": 226, "cards": 210, "selectedMessage": 150}.get(style, 0)
                 * (2 if name.startswith("large-type-") else 1))
        if style == "floatingLabels":
            width = max(math.ceil(label["measured"][0]) for label in fixture["labels"])
        if fixture["geometry"]["labelWidth"] != width:
            raise ValueError("Fixture changed the requested wrapping width")
        if fixture["geometry"]["fontSize"] != (34 if name.startswith("large-type-") else 17):
            raise ValueError("Fixture changed the requested text size")
        if fixture["count"] != count:
            raise ValueError("Fixture contains the wrong item count")
        if name in ("6-full-title", "4-unicode-title") and any(
                len(label.get("title", "")) != 160 or label["title"] == label["label"]
                for label in fixture["labels"]):
            raise ValueError("Full-title fixture does not exercise the title length limit")
        if name == "2-max-detail" and any(len(label.get("detail", "")) != 600 for label in fixture["labels"]):
            raise ValueError("Card fixture does not exercise the description length limit")
        if name.endswith("-details") and not any(label.get("detail") for label in fixture["labels"]):
            raise ValueError("Card description fixture has no descriptions")
    if report["keyboardConfirmationPassed"] is not True:
        raise ValueError("Native keyboard confirmation failed")
    extra = report["additionalChecks"]
    radius = numbers([extra.get("expandedLabelRadius")], 1)[0]
    if (extra.get("expandedPointerAndClick") is not True or radius <= 150 or
            extra.get("smallScreenFailure") is not True or extra.get("smallScreenObservationInjected") is not True):
        raise ValueError("Missing native expanded pointer or controlled screen failure evidence")
    if any(extra.get(key) is not True for key in ("nativeBackAndCancel", "styleSwitching", "nativeStylePicker")):
        raise ValueError("Missing native navigation control or style switching evidence")
    if style == "selectedMessage" and extra.get("messageTextIsNotAButton") is not True:
        raise ValueError("Missing message pointer evidence")
    if style in ("fullLabels", "cards") and extra.get("directionGuideIsNotAButton") is not True:
        raise ValueError("Missing direction guide pointer evidence")
    if style == "iconLabels" and any(extra.get(key) is not True for key in
                                     ("iconsAndCenterAreNotButtons", "nativeIconAccessibilityActions")):
        raise ValueError("Missing native icon and empty center click evidence")
    if style == "cards" and extra.get("nativeCardDescriptionClick") is not True:
        raise ValueError("Missing native description activation evidence")
    if style == "floatingLabels" and any(extra.get(key) is not True for key in
            ("nativeFloatingHitRegions", "nativeIconAccessibilityActions", "oversizedWordFailure")):
        raise ValueError("Missing floating label native checks")
    results = [{"name": fixture["name"], "issues": check_fixture(fixture)} for fixture in fixtures]
    failed = sum(bool(result["issues"]) for result in results)
    return {"passed": failed == 0, "fixtureCount": len(results), "failedFixtures": failed, "fixtures": results}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = verify(json.loads(args.report.read_text()))
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + "\n")
    for fixture in result["fixtures"]:
        kinds = sorted({issue["kind"] for issue in fixture["issues"]})
        print("FAIL:" if kinds else "PASS:", fixture["name"], ", ".join(kinds))
    print(f"{result['fixtureCount'] - result['failedFixtures']}/{result['fixtureCount']} fixtures satisfy layout constraints")
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
