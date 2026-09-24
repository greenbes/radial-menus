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


def check_fixture(fixture):
    issues = []
    geometry = fixture["geometry"]
    values = numbers([geometry[key] for key in
                      ("innerRadius", "outerRadius", "diameter", "labelRadius", "labelWidth", "fontSize", "centerRadius")], 7)
    if min(values[:3] + values[4:]) <= 0 or not values[0] < values[1]:
        raise ValueError("Invalid recorded rendering parameters")
    if fixture.get("style", "pie") == "pie" and not values[6] < values[0] < values[1] <= values[2] / 2:
        raise ValueError("Invalid pie rendering parameters")
    if geometry["labelRadius"] > geometry["diameter"] / 2:
        raise ValueError("The guide circle exceeds the panel")
    center = numbers(fixture["centerMeasured"], 2)
    if min(center) <= 0:
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
    if frame[2:] != [geometry["diameter"], geometry["diameter"]]:
        issues.append({"kind": "unexpectedPanelSize"})
    if fixture.get("style", "pie") == "selectedMessage":
        if any(fixture.get(key) is not True for key in
               ("stableSelectionLayout", "stableNavigationControl", "nativeMessageTextVerified")):
            raise ValueError("Missing stable layout or native message text evidence")
        cx, cy, cw, ch = numbers(fixture["centerBounds"], 4)
        if min(cw, ch) <= 0 or [cx, cy] != [-cw / 2, -ch / 2] or [cw, ch] != center:
            raise ValueError("Invalid central message bounds")
        d = geometry["diameter"]
        if not contained([cx, cy, cw, ch], [-d / 2, -d / 2, d, d]):
            issues.append({"kind": "centerOutsidePanel"})
        messages = fixture["messages"]
        expected = {None} | {label["id"] for label in labels}
        if len(messages) != len(expected) or {m["id"] for m in messages} != expected:
            raise ValueError("Missing or duplicated message measurements")
        for message in messages:
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
        if min(reserved_width, reserved_height) <= 0 or abs(x - expected_x) > EPSILON or abs(y - expected_y) > EPSILON:
            raise ValueError("Label position differs from recorded rendering parameters")
        rectangles.append(rectangle)
        kinds = []
        if width > reserved_width + EPSILON or height > reserved_height + EPSILON:
            kinds.append("contentExceedsLabelBox")
        d = geometry["diameter"]
        if not contained(rectangle, [-d / 2, -d / 2, d, d]):
            kinds.append("labelOutsidePanel")
        width, height = reserved_width, reserved_height
        corners = list(itertools.product((x, x + width), (y, y + height)))
        if any(math.hypot(cx, cy) > geometry["outerRadius"] + EPSILON for cx, cy in corners):
            kinds.append("labelOutsideRing")
        closest_x, closest_y = min(max(0, x), x + width), min(max(0, y), y + height)
        if fixture.get("style", "pie") == "selectedMessage":
            cx, cy, cw, ch = fixture["centerBounds"]
            if min(x + width, cx + cw) - max(x, cx) > -EPSILON and min(y + height, cy + ch) - max(y, cy) > -EPSILON:
                kinds.append("labelTouchesCenter")
        elif math.hypot(closest_x, closest_y) <= geometry["innerRadius"] + EPSILON:
            kinds.append("labelTouchesCenter")
        if count > 1:
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
    if fixture.get("style") == "fullLabels":
        issues.extend(check_direction_guide(fixture))
    return issues


def verify(report):
    expected = {f"{count}-{profile}" for count in range(1, 13) for profile in PROFILES} | {"nested", "nested-child", "large-type-4-long", "large-type-2-unicode"}
    style = report.get("style", "pie")
    if style not in ("pie", "fullLabels", "selectedMessage"):
        raise ValueError("Unknown menu style")
    if style != "pie":
        expected |= {"rich", "large-type-rich"}
    if style == "fullLabels":
        expected |= {"6-full-title", "4-unicode-title"}
    fixtures = report["fixtures"]
    if {f["name"] for f in fixtures} != expected or len(fixtures) != len(expected):
        raise ValueError("Missing or duplicate layout fixtures")
    for fixture in fixtures:
        name = fixture["name"]
        count = 6 if name in ("rich", "large-type-rich") else 2 if name == "nested" else 12 if name == "nested-child" else int(name.removeprefix("large-type-").split("-", 1)[0])
        if fixture.get("style", "pie") != style:
            raise ValueError("Fixture uses the wrong menu style")
        width = {"pie": 96, "fullLabels": 226, "selectedMessage": 150}[style]
        if fixture["geometry"]["labelWidth"] != width * (2 if name.startswith("large-type-") else 1):
            raise ValueError("Fixture changed the requested wrapping width")
        if fixture["geometry"]["fontSize"] != (34 if name.startswith("large-type-") else 17):
            raise ValueError("Fixture changed the requested text size")
        if fixture["count"] != count:
            raise ValueError("Fixture contains the wrong item count")
        if name in ("6-full-title", "4-unicode-title") and any(
                len(label.get("title", "")) != 160 or label["title"] == label["label"]
                for label in fixture["labels"]):
            raise ValueError("Full-title fixture does not exercise the title length limit")
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
    if style == "fullLabels" and extra.get("directionGuideIsNotAButton") is not True:
        raise ValueError("Missing direction guide pointer evidence")
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
