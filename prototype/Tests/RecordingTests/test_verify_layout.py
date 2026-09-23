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
                                       "smallScreenFailure": True, "smallScreenObservationInjected": True}}
        self.assertTrue(verifier.verify(report)["passed"])
        for mutation in ("missing", "duplicate", "confirmation", "count", "pointer", "screen", "font", "width"):
            changed = copy.deepcopy(report)
            if mutation == "missing":
                changed["fixtures"].pop()
            elif mutation == "duplicate":
                changed["fixtures"].append(changed["fixtures"][0])
            elif mutation == "count":
                changed["fixtures"][0] = {**fixture(2), "name": "1-short"}
            elif mutation in ("pointer", "screen", "font", "width"):
                changed["additionalChecks"]["expandedPointerAndClick" if mutation == "pointer" else "smallScreenFailure"] = False
            else:
                changed["keyboardConfirmationPassed"] = False
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                verifier.verify(changed)


if __name__ == "__main__":
    unittest.main()
