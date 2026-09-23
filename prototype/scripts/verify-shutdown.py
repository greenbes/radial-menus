"""Launch real app processes and check recorded shutdown evidence independently."""

import json
from pathlib import Path
import subprocess
import sys
import time


STAGES = {
    "idle": "Idle", "opening": "Presenting", "active": "Active",
    "moving": "Active", "dismissing": "Dismissing", "recovering": "Unavailable",
    "missing-release": "Idle",
}


def verify(records, stage):
    def require(condition, message):
        if not condition:
            raise ValueError(f"{stage}: {message}")

    def one(predicate, message):
        matches = [(i, value) for i, value in enumerate(records) if predicate(value)]
        require(len(matches) == 1, message)
        return matches[0]

    checkpoint_index, checkpoint = one(
        lambda r: r["kind"] == "shutdownProbe", "missing or duplicate starting observation")
    require(checkpoint.get("stage") == stage and checkpoint.get("phase") == STAGES[stage],
            "wrong starting state or failed setup")
    require(checkpoint["moving"] == (stage == "moving"), "wrong starting movement state")
    require(checkpoint["panelVisible"] == (stage in ("opening", "active", "moving")),
            "wrong native panel visibility")
    request_index, request = one(
        lambda r: r.get("message") == "Application termination requested", "missing or duplicate quit request")
    stop_index, stop = one(lambda r: r.get("event") == "stop", "missing or duplicate stop transition")
    require(checkpoint_index < request_index < stop_index, "incorrect termination ordering")
    require(not stop["running"] and not stop["moving"], "stop did not disable input and movement")
    outputs = [(i, output) for i, record in enumerate(records) for output in record.get("outputs", [])]
    shutdown = [(i, output) for i, output in outputs if output["type"] == "shutdown"]
    require(len(shutdown) == 1, "missing or duplicate shutdown result")
    shutdown_index, result = shutdown[0]
    require(shutdown_index > stop_index, "shutdown did not await an acknowledgment or deadline")
    require(result["result"] == ("failed" if stage == "missing-release" else "completed"),
            "incorrect shutdown outcome")
    session_results = [(i, output) for i, output in outputs if output["type"] != "shutdown"]
    if stage in ("idle", "missing-release"):
        require(not session_results, "invented a session result")
    else:
        require(len(session_results) == 1, "missing or duplicate session result")
        index, outcome = session_results[0]
        require(index < shutdown_index, "shutdown preceded session completion")
        if stage == "dismissing":
            require(index > stop_index and outcome["type"] == "selected" and outcome["value"] == "blue",
                    "lost the committed choice during shutdown")
        elif stage == "recovering":
            require(index < stop_index and outcome["type"] == "failed" and
                    not outcome["cleanupConfirmed"], "did not preserve the injected cleanup failure")
        else:
            require(index > stop_index and outcome["type"] == "cancelled" and
                    outcome["reason"] == "applicationStopping", "wrong cancellation result")
    resources_index, resources = one(
        lambda r: r["kind"] == "shutdownResources", "missing or duplicate resource observation")
    require(resources_index > shutdown_index, "resource observation preceded shutdown result")
    for field in ("panelVisible", "panelResources", "controllerResources", "deadlineCount", "movementCount"):
        require(resources[field] == 0, f"resource remains: {field}")
    for field in ("backgroundMonitoringRestored", "inputHandlersReleased"):
        require(resources[field] is True, f"resource was not restored: {field}")
    final_index, final = one(lambda r: r.get("message") == "Application will terminate",
                           "AppKit did not confirm termination")
    require(final_index > resources_index, "incorrect termination reply ordering")
    elapsed = final["uptime"] - request["uptime"]
    require(0 <= elapsed < 8, "shutdown exceeded process-test deadline")
    if stage == "missing-release":
        require(elapsed >= 3.8, "overall deadline fired too early")
        require(records[shutdown_index]["event"] == "shutdownDeadline", "failure was not the overall deadline")
    else:
        require(records[shutdown_index]["event"] == "resourcesReleased", "success lacks native release acknowledgment")
    if stage == "moving":
        positions = {tuple(r["frame"]) for r in records[:checkpoint_index] if "frame" in r}
        require(len(positions) > 1, "no native displacement before moving shutdown")
    return {"stage": stage, "shutdownSeconds": elapsed, "result": result["result"]}


def main():
    executable, directory = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    results = []
    for stage in STAGES:
        recording = directory / f"{stage}.jsonl"
        started = time.monotonic()
        with (directory / f"{stage}.log").open("wb") as output:
            process = subprocess.Popen([str(executable), "--shutdown-test", stage, "--record", str(recording)],
                                       stdout=output, stderr=subprocess.STDOUT)
            try:
                code = process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                raise RuntimeError(f"{stage}: app process did not exit") from None
        if code != 0:
            raise RuntimeError(f"{stage}: app exited with {code}")
        records = [json.loads(line) for line in recording.read_text().splitlines()]
        result = verify(records, stage)
        result.update(processExitCode=code, processSeconds=time.monotonic() - started)
        results.append(result)
        print("PASS:", json.dumps(result), flush=True)
    (directory / "report.json").write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
