import copy
import importlib.util
import math
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[2] / "scripts" / "verify-layout.py"
spec = importlib.util.spec_from_file_location("verify_layout", path)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)

GEOMETRY = {"innerRadius": 46, "outerRadius": 150, "diameter": 360,
            "labelRadius": 100, "labelWidth": 96, "fontSize": 17, "centerRadius": 42}


def fixture(count=4, size=(20, 20), geometry=GEOMETRY):
    width, height = size
    labels = []
    for index in range(count):
        angle = index * 2 * math.pi / count
        labels.append({"id": str(index), "measured": list(size), "normal": list(size), "selected": list(size),
                       "rectangle": [math.sin(angle) * geometry["labelRadius"] - width / 2,
                                     -math.cos(angle) * geometry["labelRadius"] - height / 2, width, height]})
    return {"name": "fixture", "count": count, "labels": labels, "keyboardSteps": count, "geometry": dict(geometry), "centerMeasured": [36, 32],
            "frame": [-500, -100, 360, 360], "screenBounds": [-1000, -200, 1200, 900]}


def kinds(value):
    return {issue["kind"] for issue in verifier.check_fixture(value)}


class LayoutRecordingTests(unittest.TestCase):
    def test_full_labels_require_correct_connections_and_native_text_evidence(self):
        value = fixture()
        value.update(style="fullLabels", stableSelectionLayout=True, stableNavigationControl=True,
                     nativeFullTitleTextVerified=True, nativeLabelFramesVerified=True,
                     directionGuide={"radius": 44, "markerRadius": 1, "connections": [
                         {"id": "0", "marker": [0, -44], "labelEdge": [0, -90]},
                         {"id": "1", "marker": [44, 0], "labelEdge": [90, 0]},
                         {"id": "2", "marker": [0, 44], "labelEdge": [0, 90]},
                         {"id": "3", "marker": [-44, 0], "labelEdge": [-90, 0]}]})
        self.assertEqual(kinds(value), set())
        card = copy.deepcopy(value)
        card.update(style="cards", nativeCardTextVerified=True)
        self.assertEqual(kinds(card), set())
        card["nativeCardTextVerified"] = False
        with self.assertRaises(ValueError):
            kinds(card)
        changed = copy.deepcopy(value)
        changed["directionGuide"]["connections"][0]["marker"] = [44, 0]
        self.assertIn("markerHasWrongDirection", kinds(changed))
        for endpoint in ([0, 0], [0, -100], [0, -110], [1, -90], [0, 90]):
            changed = copy.deepcopy(value)
            changed["directionGuide"]["connections"][0]["labelEdge"] = endpoint
            self.assertIn("connectionMissesLabelEdge", kinds(changed))
        changed = copy.deepcopy(value)
        changed["directionGuide"]["connections"][0]["labelEdge"] = [0, 100]
        self.assertIn("connectionCrossesAnotherLabel", kinds(changed))
        for mutation in ("nativeFullTitleTextVerified", "nativeLabelFramesVerified",
                         "stableNavigationControl", "stableSelectionLayout", "identity", "center", "panel", "nan"):
            changed = copy.deepcopy(value)
            if mutation == "identity":
                changed["directionGuide"]["connections"][0]["id"] = "1"
            elif mutation in ("center", "panel", "nan"):
                changed["directionGuide"]["radius"] = {"center": 40, "panel": 500, "nan": math.nan}[mutation]
            else:
                changed[mutation] = False
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                kinds(changed)

    def test_connection_intersection_checks_finite_segments(self):
        box = [10, 10, 10, 10]
        for start, end in (([0, 15], [30, 15]), ([15, 30], [15, 0]), ([0, 0], [30, 30]),
                           ([12, 12], [18, 18])):
            self.assertTrue(verifier.segment_intersects_box(start, end, box))
        for start, end in (([0, 0], [9, 9]), ([21, 21], [30, 30]), ([0, 5], [30, 5]),
                           ([5, 0], [5, 30])):
            self.assertFalse(verifier.segment_intersects_box(start, end, box))

    def test_selected_messages_must_include_neutral_and_every_item_and_fit(self):
        value = fixture()
        value.update(style="selectedMessage", stableSelectionLayout=True, stableNavigationControl=True,
                     nativeMessageTextVerified=True, nativeLabelFramesVerified=True, centerBounds=[-18, -16, 36, 32],
                     messages=[{"id": item_id, "measured": [36, 32]} for item_id in [None, "0", "1", "2", "3"]])
        for label, rectangle in zip(value["labels"], [[-10, -120, 20, 20], [100, -10, 20, 20],
                                                     [-10, 100, 20, 20], [-120, -10, 20, 20]]):
            label.update(rectangle=rectangle, cornerRadius=10)
        self.assertEqual(kinds(value), set())
        for shift in [-6, 6]:
            changed = copy.deepcopy(value)
            changed["labels"][0]["rectangle"][1] += shift
            self.assertIn("labelIsNotTangent", kinds(changed))
        # A tall external label can cross an angular boundary while remaining
        # tangent at the correct direction and disjoint from the other labels.
        tall = copy.deepcopy(value)
        tall["labels"][1].update(rectangle=[100, -110, 20, 220], measured=[20, 220],
                                 normal=[20, 220], selected=[20, 220])
        tall["geometry"].update(outerRadius=200, diameter=440)
        tall["frame"][2:] = [440, 440]
        self.assertEqual(kinds(tall), set())
        oversized = copy.deepcopy(value)
        oversized["messages"][2]["measured"][1] = 33
        self.assertIn("messageExceedsCenter", kinds(oversized))
        for mutation in ("neutral", "item", "duplicate", "nonfinite", "stability", "button", "native_text", "native_frames", "bounds"):
            changed = copy.deepcopy(value)
            if mutation == "neutral":
                changed["messages"].pop(0)
            elif mutation == "item":
                changed["messages"].pop()
            elif mutation == "duplicate":
                changed["messages"][1] = changed["messages"][0]
            elif mutation == "nonfinite":
                changed["messages"][0]["measured"] = [math.nan, 20]
            elif mutation == "stability":
                changed["stableSelectionLayout"] = False
            elif mutation == "button":
                changed["stableNavigationControl"] = False
            elif mutation == "native_text":
                changed["nativeMessageTextVerified"] = False
            elif mutation == "native_frames":
                changed["nativeLabelFramesVerified"] = False
            else:
                changed["centerBounds"][0] = 0
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                kinds(changed)

    def test_small_measured_labels_fit_every_supported_item_count(self):
        for count in range(1, 13):
            with self.subTest(count=count):
                self.assertEqual(kinds(fixture(count)), set())

    def test_actual_measurements_must_fit_the_reserved_bounds(self):
        for width, height in ((40, 80), (97, 20)):
            value = fixture(1)
            value["labels"][0].update(measured=[width, height], normal=[width, height], selected=[width, height])
            self.assertIn("contentExceedsLabelBox", kinds(value))
        self.assertNotIn("contentExceedsLabelBox", kinds(fixture(1, (96, 100))))

    def test_center_control_must_fit_its_circle(self):
        value = fixture()
        value["centerMeasured"] = [100, 100]
        self.assertIn("centerContentExceedsCircle", kinds(value))

    def test_dense_labels_cross_their_sectors_and_overlap(self):
        failures = kinds(fixture(12, (90, 60)))
        self.assertIn("labelOutsideOwnSector", failures)
        self.assertIn("labelEnvelopesOverlap", failures)

    def test_outer_arc_and_center_intersection_are_checked(self):
        self.assertIn("labelOutsideRing", kinds(fixture(1, (200, 100))))
        centered = {**GEOMETRY, "labelRadius": 0}
        # All corners lie outside the center circle; corner checks alone miss it.
        failures = kinds(fixture(1, (120, 120), centered))
        self.assertIn("labelTouchesCenter", failures)

    def test_panel_is_checked_against_observed_screen_and_expected_size(self):
        value = fixture()
        value["frame"][0] = -1100
        self.assertIn("panelOutsideScreen", kinds(value))
        value = fixture()
        value["frame"][2] = 361
        self.assertIn("unexpectedPanelSize", kinds(value))

    def test_invalid_incomplete_or_inconsistent_measurements_cannot_pass(self):
        for changed in (
            {"measured": [math.nan, 20]}, {"normal": [40, 20]},
            {"rectangle": [0, 0, 20, 20]}, {"selected": [20, 0]},
        ):
            value = fixture()
            value["labels"][0].update(changed)
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                kinds(value)
        value = fixture()
        value["keyboardSteps"] = 0
        with self.assertRaises(ValueError):
            kinds(value)

    def test_report_requires_every_fixture_and_successful_native_confirmation(self):
        fixtures = []
        for count in range(1, 13):
            for profile in verifier.PROFILES:
                value = fixture(count)
                value["name"] = f"{count}-{profile}"
                fixtures.append(value)
        for name in ("nested", "nested-child"):
            value = fixture(2 if name == "nested" else 12)
            value["name"] = name
            fixtures.append(value)
        for name, count in (("large-type-4-long", 4), ("large-type-2-unicode", 2)):
            value = fixture(count, geometry={**GEOMETRY, "fontSize": 34, "labelWidth": 192})
            value["name"] = name
            fixtures.append(value)
        report = {"fixtures": fixtures, "keyboardConfirmationPassed": True,
                  "additionalChecks": {"expandedPointerAndClick": True, "expandedLabelRadius": 250,
                                       "nativeBackAndCancel": True, "styleSwitching": True, "nativeStylePicker": True,
                                       "smallScreenFailure": True, "smallScreenObservationInjected": True}}
        self.assertTrue(verifier.verify(report)["passed"])
        for mutation in ("missing", "duplicate", "confirmation", "count", "pointer", "screen", "font", "width", "style", "controls", "picker"):
            changed = copy.deepcopy(report)
            if mutation == "missing":
                changed["fixtures"].pop()
            elif mutation == "duplicate":
                changed["fixtures"].append(changed["fixtures"][0])
            elif mutation == "count":
                changed["fixtures"][0] = {**fixture(2), "name": "1-short"}
            elif mutation in ("pointer", "screen"):
                changed["additionalChecks"]["expandedPointerAndClick" if mutation == "pointer" else "smallScreenFailure"] = False
            elif mutation in ("font", "width"):
                changed["fixtures"][0]["geometry"]["fontSize" if mutation == "font" else "labelWidth"] += 1
            elif mutation == "style":
                changed["fixtures"][0]["style"] = "selectedMessage"
            elif mutation in ("controls", "picker"):
                changed["additionalChecks"]["nativeBackAndCancel" if mutation == "controls" else "nativeStylePicker"] = False
            else:
                changed["keyboardConfirmationPassed"] = False
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                verifier.verify(changed)


if __name__ == "__main__":
    unittest.main()
