import copy
import unittest

from test_verify_layout import verifier


def fixture():
    rectangles = [[-40, -140, 80, 40], [100, -30, 160, 60], [-50, 100, 100, 80], [-220, -20, 120, 40]]
    titles = ["Red", "Open recent documents", "Supercalifragilisticexpialidocious", "123456789 1234567890"]
    lines = [["Red"], ["Open recent", "documents"], [titles[2]], [titles[3]]]
    labels = [{"id": str(i), "rectangle": r, "normal": r[2:], "selected": r[2:], "measured": r[2:],
               "cornerRadius": 10, "title": titles[i], "lines": lines[i]} for i, r in enumerate(rectangles)]
    states = []
    for selected in [None, "0", "1", "2", "3"]:
        states.append({"selectedID": selected, "centerAlpha": 0, "gapAlpha": [0] * 4, "labels": [
            {"id": str(i), "fill": [0, 0.4, 1, 1] if str(i) == selected else [0.9, 0.9, 0.9, 1],
             "outline": [1, 1, 1, 1] if str(i) == selected else [0.9, 0.9, 0.9, 1]} for i in range(4)]})
    return {"name": "fixture", "style": "floatingLabels", "count": 4, "labels": labels, "keyboardSteps": 4,
            "geometry": {"innerRadius": 100, "outerRadius": 300, "diameter": 580, "windowSize": [580, 420],
                         "labelRadius": 100, "labelWidth": 160, "fontSize": 17, "centerRadius": 0},
            "frame": [0, 0, 580, 420], "screenBounds": [0, 0, 1200, 900], "centerMeasured": [0, 0],
            "centerBounds": [0, 0, 0, 0], "directionGuide": {}, "iconStates": [], "floatingStates": states,
            "stableSelectionLayout": True, "nativeFullTitleTextVerified": True, "nativeLabelFramesVerified": True}


class FloatingLabelRecordingTests(unittest.TestCase):
    def test_accepts_variable_widths_rectangular_window_and_whole_long_word(self):
        self.assertEqual(verifier.check_fixture(fixture()), [])

    def test_rejects_geometry_text_and_pixel_counterexamples(self):
        mutations = [
            (lambda f: f["labels"][0]["rectangle"].__setitem__(1, -141), "labelIsNotTangent"),
            (lambda f: f["labels"][1]["rectangle"].__setitem__(2, 170), "labelDoesNotFitIntrinsicSize"),
            (lambda f: f["labels"][1].__setitem__("lines", ["Open recent documents"]), "lineExceedsCharacterLimit"),
            (lambda f: f["labels"][2].__setitem__("lines", ["Supercalifragilistic", "expialidocious"]), "wrappedTextChangedWords"),
            (lambda f: f["labels"][3].__setitem__("lines", ["123456789", "1234567890"]), "incorrectWordWrapping"),
            (lambda f: f["floatingStates"][0].__setitem__("centerAlpha", 1), "centerOrRingIsVisible"),
            (lambda f: f["floatingStates"][1]["gapAlpha"].__setitem__(0, 1), "centerOrRingIsVisible"),
            (lambda f: f["floatingStates"][1]["labels"][1].__setitem__("fill", [0, 0.4, 1, 1]), "wrongLabelHighlighted"),
            (lambda f: f["floatingStates"][1]["labels"][0].__setitem__("outline", [0, 0.4, 1, 1]), "missingThickSelectionOutline"),
            (lambda f: f["frame"].__setitem__(3, 580), "unexpectedPanelSize"),
        ]
        for mutate, expected in mutations:
            value = fixture()
            mutate(value)
            with self.subTest(expected=expected):
                self.assertIn(expected, {issue["kind"] for issue in verifier.check_fixture(value)})

    def test_requires_native_evidence_for_every_selection_and_no_center_or_ring(self):
        for mutation in ("missing_state", "center", "ring", "nativeFullTitleTextVerified", "nativeLabelFramesVerified", "stableSelectionLayout"):
            value = copy.deepcopy(fixture())
            if mutation == "missing_state":
                value["floatingStates"].pop()
            elif mutation == "center":
                value["centerBounds"] = [-10, -10, 20, 20]
            elif mutation == "ring":
                value["iconStates"] = [{}]
            else:
                value[mutation] = False
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                verifier.check_fixture(value)


if __name__ == "__main__":
    unittest.main()
