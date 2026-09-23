import copy
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[2] / "scripts" / "verify-reconnection.py"
spec = importlib.util.spec_from_file_location("verify_reconnection", path)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def fixture():
    common = {"kind": "transition", "session": 1, "owner": 7, "phase": "Active", "moving": True}
    return [
        {"kind": "transition", "event": "connected", "connection": 7, "controller": "Physical fixture"},
        {**common, "event": "controllerFrame", "connection": 7, "continuous": True,
         "rightStick": [1, 0], "frame": [100, 100, 360, 360]},
        {**common, "event": "moved", "frame": [130, 100, 360, 360]},
        {**common, "event": "disconnected", "connection": 7, "moving": False, "phase": "Dismissing"},
        {"kind": "transition", "event": "dismissed", "phase": "Idle", "outputs": [
            {"type": "cancelled", "reason": "controllerLost", "session": 1}]},
        {"kind": "transition", "event": "connected", "connection": 8, "controller": "Physical fixture", "phase": "Idle"},
        {"kind": "transition", "event": "controllerFrame", "connection": 8, "session": 2,
         "owner": 8, "continuous": True, "buttons": ["menu"], "phase": "Preparing"},
        {"kind": "transition", "event": "controllerFrame", "connection": 8, "session": 2,
         "continuous": True, "buttons": ["confirm"], "selected": "red", "phase": "Dismissing"},
        {"kind": "transition", "event": "dismissed", "phase": "Idle", "outputs": [
            {"type": "selected", "value": "red", "session": 2}]},
    ]


class ReconnectionRecordingTests(unittest.TestCase):
    def test_complete_trace_and_neutral_before_loss_are_distinguished(self):
        result = verifier.verify(fixture(), "Physical fixture")
        self.assertTrue(result["passed"])
        self.assertTrue(result["movingAtDisconnect"])
        records = fixture()
        records[2]["moving"] = False
        result = verifier.verify(records, "Physical fixture")
        self.assertTrue(result["passed"])
        self.assertFalse(result["movingAtDisconnect"])

    def test_missing_or_contradictory_evidence_fails(self):
        mutations = [
            (1, "connection", 9), (1, "continuous", False), (1, "rightStick", [0, 0]),
            (2, "frame", [100, 100, 360, 360]), (3, "connection", 9), (3, "moving", True),
            (4, "outputs", [{"type": "cancelled", "reason": "focusLost", "session": 1}]),
            (5, "connection", 7), (6, "buttons", []), (7, "buttons", []),
            (8, "outputs", [{"type": "selected", "value": "blue", "session": 2}]),
        ]
        for index, key, value in mutations:
            with self.subTest(index=index, key=key):
                records = copy.deepcopy(fixture())
                records[index][key] = value
                self.assertFalse(verifier.verify(records, "Physical fixture")["passed"])

    def test_wrong_controller_incomplete_and_duplicate_results_fail(self):
        self.assertFalse(verifier.verify(fixture(), "Different controller")["passed"])
        self.assertFalse(verifier.verify(fixture()[:-1], "Physical fixture")["passed"])
        for index in (4, 8):
            records = fixture()
            records.insert(index, copy.deepcopy(records[index]))
            self.assertFalse(verifier.verify(records, "Physical fixture")["passed"])


if __name__ == "__main__":
    unittest.main()
