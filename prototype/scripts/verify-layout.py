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


def check_fixture(fixture):
    issues = []
    geometry = fixture["geometry"]
    values = numbers([geometry[key] for key in
                      ("innerRadius", "outerRadius", "diameter", "labelRadius", "labelWidth", "fontSize", "centerRadius")], 7)
    if min(values[:3] + values[4:]) <= 0 or not values[6] < values[0] < values[1] <= values[2] / 2:
        raise ValueError("Invalid recorded rendering parameters")
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
        width, height = reserved_width, reserved_height
        corners = list(itertools.product((x, x + width), (y, y + height)))
        if any(math.hypot(cx, cy) > geometry["outerRadius"] + EPSILON for cx, cy in corners):
            kinds.append("labelOutsideRing")
        closest_x, closest_y = min(max(0, x), x + width), min(max(0, y), y + height)
        if math.hypot(closest_x, closest_y) <= geometry["innerRadius"] + EPSILON:
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
    return issues


def verify(report):
    expected = {f"{count}-{profile}" for count in range(1, 13) for profile in PROFILES} | {"nested", "nested-child", "large-type-4-long", "large-type-2-unicode"}
    fixtures = report["fixtures"]
    if {f["name"] for f in fixtures} != expected or len(fixtures) != len(expected):
        raise ValueError("Missing or duplicate layout fixtures")
    for fixture in fixtures:
        name = fixture["name"]
        count = 2 if name == "nested" else 12 if name == "nested-child" else int(name.removeprefix("large-type-").split("-", 1)[0])
        if fixture["geometry"]["labelWidth"] != (192 if name.startswith("large-type-") else 96):
            raise ValueError("Fixture changed the requested wrapping width")
        if fixture["geometry"]["fontSize"] != (34 if name.startswith("large-type-") else 17):
            raise ValueError("Fixture changed the requested text size")
        if fixture["count"] != count:
            raise ValueError("Fixture contains the wrong item count")
    if report["keyboardConfirmationPassed"] is not True:
        raise ValueError("Native keyboard confirmation failed")
    extra = report["additionalChecks"]
    radius = numbers([extra.get("expandedLabelRadius")], 1)[0]
    if (extra.get("expandedPointerAndClick") is not True or radius <= 150 or
            extra.get("smallScreenFailure") is not True or extra.get("smallScreenObservationInjected") is not True):
        raise ValueError("Missing native expanded pointer or controlled screen failure evidence")
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
