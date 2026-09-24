import copy
import math
import unittest

from test_verify_layout import fixture, kinds


def icon_fixture():
    value = fixture()
    value.update(style="iconLabels", stableSelectionLayout=True,
                 nativeFullTitleTextVerified=True, nativeLabelFramesVerified=True,
                 centerMeasured=[0, 0], centerBounds=[0, 0, 0, 0], directionGuide={})
    value["geometry"]["centerRadius"] = 0
    value["iconStates"] = []
    for selected in [None, "0", "1", "2", "3"]:
        icons = []
        for index in range(4):
            fill = [0.1, 0.4, 0.9, 1] if str(index) == selected else [0.8, 0.8, 0.8, 1]
            icons.append({"id": str(index), "center": [math.sin(index * math.pi / 2) * 30, -math.cos(index * math.pi / 2) * 30],
                          "normal": [10, 10], "selected": [11, 11], "iconFill": fill[:], "labelFill": fill[:],
                          "gapPixel": [0, 0, 0, 0]})
        value["iconStates"].append({"selectedID": selected, "radius": 30, "badgeRadius": 10,
                                   "centerPixel": [0, 0, 0, 0], "icons": icons})
    return value


class IconRecordingTests(unittest.TestCase):
    def test_accepts_matching_highlights_with_empty_center_and_gaps(self):
        self.assertEqual(kinds(icon_fixture()), set())

    def test_rejects_wrong_or_missing_visual_selection(self):
        for mutation in ("different_color", "transparent_icon", "no_highlight", "extra_highlight"):
            value = icon_fixture()
            state = value["iconStates"][1]
            if mutation == "different_color":
                state["icons"][0]["iconFill"][0] = 1
            elif mutation == "transparent_icon":
                state["icons"][0]["iconFill"][3] = 0
            elif mutation == "no_highlight":
                state["icons"][0] = copy.deepcopy(value["iconStates"][0]["icons"][0])
            else:
                state["icons"][1]["iconFill"] = state["icons"][0]["iconFill"][:]
                state["icons"][1]["labelFill"] = state["icons"][0]["labelFill"][:]
            with self.subTest(mutation=mutation):
                self.assertTrue(kinds(value) & {"iconAndLabelColorsDiffer", "wrongIconHighlighted"})

    def test_rejects_visible_center_lines_wrong_direction_and_clipped_glyph(self):
        for mutation, expected in (("center", "centerIsNotEmpty"), ("line", "connectingLineIsVisible"),
                                   ("direction", "iconHasWrongDirection"), ("glyph", "glyphExceedsBadge")):
            value = icon_fixture()
            for state in value["iconStates"]:
                if mutation == "center":
                    state["centerPixel"][3] = 1
                elif mutation == "line":
                    state["icons"][0]["gapPixel"][3] = 1
                elif mutation == "direction":
                    state["icons"][0]["center"] = [30, 0]
                else:
                    state["icons"][0]["selected"] = [20, 20]
            with self.subTest(mutation=mutation):
                self.assertIn(expected, kinds(value))

    def test_rejects_overlapping_icon_badges(self):
        value = icon_fixture()
        value["geometry"]["innerRadius"] = 60
        for state in value["iconStates"]:
            state["badgeRadius"] = 22
        self.assertIn("iconBadgesOverlap", kinds(value))

    def test_rejects_absent_inconsistent_and_invalid_observations(self):
        for mutation in ("state", "identity", "nan", "center", "connections", "native_text", "position"):
            value = icon_fixture()
            if mutation == "state":
                value["iconStates"].pop()
            elif mutation == "identity":
                value["iconStates"][1]["icons"][0]["id"] = "missing"
            elif mutation == "nan":
                value["iconStates"][1]["icons"][0]["iconFill"][0] = math.nan
            elif mutation == "center":
                value["centerBounds"] = [-20, -20, 40, 40]
            elif mutation == "connections":
                value["directionGuide"] = {"connections": []}
            elif mutation == "native_text":
                value["nativeFullTitleTextVerified"] = False
            else:
                value["iconStates"][1]["icons"][0]["center"] = [30, 0]
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                kinds(value)
