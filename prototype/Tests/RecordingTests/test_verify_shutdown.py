import copy
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[2] / "scripts" / "verify-shutdown.py"
spec = importlib.util.spec_from_file_location("verify_shutdown", path)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def fixture(stage="idle"):
    records = [
        {"kind": "shutdownProbe", "stage": stage, "phase": verifier.STAGES[stage],
         "moving": False, "panelVisible": False},
        {"kind": "message", "message": "Application termination requested", "uptime": 10},
        {"kind": "transition", "event": "stop", "running": False, "moving": False},
    ]
    if stage == "dismissing":
        records.append({"kind": "transition", "event": "dismissed",
                        "outputs": [{"type": "selected", "value": "blue"}]})
    if stage == "preparing":
        records.append({"kind": "transition", "event": "dismissed",
                        "outputs": [{"type": "cancelled", "reason": "applicationStopping"}]})
    records.extend([
        {"kind": "transition", "event": "shutdownDeadline" if stage == "missing-release" else "resourcesReleased",
         "outputs": [{"type": "shutdown", "result": "failed" if stage == "missing-release" else "completed"}]},
        {"kind": "shutdownResources", "panelVisible": False, "panelResources": False,
         "controllerResources": False, "deadlineCount": 0, "movementCount": 0,
         "backgroundMonitoringRestored": True, "inputHandlersReleased": True},
        {"kind": "message", "message": "Application will terminate", "uptime": 14.1},
    ])
    return records


class ShutdownRecordingTests(unittest.TestCase):
    def test_success_committed_choice_and_timeout_require_distinct_results(self):
        for stage in ("idle", "preparing", "dismissing", "missing-release"):
            with self.subTest(stage=stage):
                self.assertEqual(verifier.verify(fixture(stage), stage)["stage"], stage)

    def test_missing_or_duplicated_evidence_is_rejected(self):
        for index in range(len(fixture())):
            with self.subTest(index=index):
                records = fixture()
                records.pop(index)
                with self.assertRaises((ValueError, KeyError)):
                    verifier.verify(records, "idle")
                records = fixture()
                records.insert(index, copy.deepcopy(records[index]))
                with self.assertRaises(ValueError):
                    verifier.verify(records, "idle")

    def test_resource_leaks_wrong_order_and_wrong_choice_are_rejected(self):
        for field in ("panelVisible", "panelResources", "controllerResources", "deadlineCount", "movementCount",
                      "backgroundMonitoringRestored", "inputHandlersReleased"):
            with self.subTest(field=field):
                records = fixture()
                records[-2][field] = not records[-2][field]
                with self.assertRaises(ValueError):
                    verifier.verify(records, "idle")
        records = fixture()
        records[-1], records[-2] = records[-2], records[-1]
        with self.assertRaises(ValueError):
            verifier.verify(records, "idle")
        records = fixture("dismissing")
        records[3]["outputs"][0]["value"] = "red"
        with self.assertRaises(ValueError):
            verifier.verify(records, "dismissing")

    def test_false_success_and_early_or_late_timeout_are_rejected(self):
        records = fixture("missing-release")
        records[3]["outputs"][0]["result"] = "completed"
        with self.assertRaises(ValueError):
            verifier.verify(records, "missing-release")
        for end in (10.1, 18.1):
            records = fixture("missing-release")
            records[-1]["uptime"] = end
            with self.assertRaises(ValueError):
                verifier.verify(records, "missing-release")


if __name__ == "__main__":
    unittest.main()
