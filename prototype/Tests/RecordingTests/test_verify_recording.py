import copy
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[2] / "scripts" / "verify-recording.py"
spec = importlib.util.spec_from_file_location("verify_recording", path)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def fixture():
    common = {"kind": "transition", "session": 1, "owner": 7, "phase": "Active",
              "moving": False, "outputs": [], "bounds": [0, 0, 1000, 1000],
              "displays": [{"id": "display", "bounds": [0, 0, 1000, 1000]}]}
    return [
        {"kind": "transition", "event": "connected", "connection": 7, "controller": "Physical fixture"},
        {**common, "event": "controllerFrame", "connection": 7, "continuous": True,
         "rightStick": [1, 0], "moving": True, "frame": [100, 100, 360, 360]},
        {**common, "event": "moved", "moving": True, "frame": [130, 100, 360, 360]},
        {**common, "event": "controllerFrame", "connection": 7, "continuous": True,
         "rightStick": [0, 0], "frame": [130, 100, 360, 360]},
        {**common, "event": "controllerFrame", "connection": 7, "continuous": True,
         "rightStick": [0, 0], "buttons": ["confirm"], "phase": "Dismissing"},
        {"kind": "transition", "event": "dismissed", "phase": "Idle", "moving": False,
         "outputs": [{"type": "selected", "session": 1, "value": "red", "menuPath": ["root"]}]},
    ]


class RecordingTests(unittest.TestCase):
    def test_spanning_adjacent_displays_is_valid_but_spanning_a_gap_is_not(self):
        displays = [{"id": "left", "bounds": [0, 0, 300, 1000]},
                    {"id": "right", "bounds": [300, 0, 700, 1000]}]
        records = fixture()
        for record in records:
            if "frame" in record:
                record["displays"] = copy.deepcopy(displays)
        self.assertTrue(verifier.verify(records, "Physical fixture")["passed"])
        records[2]["displays"][1]["bounds"] = [310, 0, 690, 1000]
        self.assertFalse(verifier.verify(records, "Physical fixture")["passed"])

    def test_missing_display_geometry_cannot_prove_visibility(self):
        records = fixture()
        records[2].pop("displays")
        self.assertFalse(verifier.verify(records, "Physical fixture")["passed"])

    def test_complete_movement_release_confirmation_and_dismissal_passes(self):
        self.assertTrue(verifier.verify(fixture(), "Physical fixture")["passed"])

    def test_movement_between_old_and_new_thresholds_and_release_at_boundary_passes(self):
        records = fixture()
        records[1]["rightStick"] = [0.15, 0]
        records[3]["rightStick"] = [0.1, 0]
        self.assertTrue(verifier.verify(records, "Physical fixture")["passed"])

    def test_stopped_above_new_dead_zone_is_not_neutral(self):
        records = fixture()
        records[3]["rightStick"] = [0.15, 0]
        self.assertFalse(verifier.verify(records, "Physical fixture")["passed"])

    def test_missing_or_inconsistent_evidence_fails(self):
        mutations = [
            (1, "rightStick", [0, 0]),
            (1, "connection", 9),
            (1, "continuous", False),
            (2, "frame", [100, 100, 360, 360]),
            (2, "frame", [900, 100, 360, 360]),
            (3, "moving", True),
            (4, "buttons", []),
            (5, "event", "confirm"),
            (5, "phase", "Dismissing"),
        ]
        for index, key, value in mutations:
            with self.subTest(index=index, key=key):
                records = copy.deepcopy(fixture())
                records[index][key] = value
                self.assertFalse(verifier.verify(records, "Physical fixture")["passed"])

    def test_different_controller_and_incomplete_recording_fail(self):
        self.assertFalse(verifier.verify(fixture(), "Some other device")["passed"])
        self.assertFalse(verifier.verify(fixture()[:-1], "Physical fixture")["passed"])


if __name__ == "__main__":
    unittest.main()
