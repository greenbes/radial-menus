#!/usr/bin/env python3
"""Check recorded physical movement through neutral release and completed choice."""
import argparse
import json
import math
from pathlib import Path


def covered_by_displays(frame, displays):
    """Subtract display rectangles; any remaining piece is invisible space."""
    if not displays or len(frame) != 4 or not all(math.isfinite(v) for v in frame):
        return False
    x, y, width, height = frame
    if width <= 0 or height <= 0:
        return False
    remaining = [(x, y, x + width, y + height)]
    for display in displays:
        bounds = display.get("bounds", [])
        if len(bounds) != 4 or not all(math.isfinite(v) for v in bounds):
            return False
        bx, by, bw, bh = bounds
        if bw <= 0 or bh <= 0:
            return False
        pieces = []
        for left, bottom, right, top in remaining:
            il, ib = max(left, bx), max(bottom, by)
            ir, it = min(right, bx + bw), min(top, by + bh)
            if il >= ir or ib >= it:
                pieces.append((left, bottom, right, top))
            else:
                pieces.extend(p for p in [(left, bottom, il, top), (ir, bottom, right, top),
                    (il, bottom, ir, ib), (il, it, ir, top)] if p[0] < p[2] and p[1] < p[3])
        remaining = pieces
    return not remaining


def verify(records, controller_name):
    controllers = {}
    sessions = {}
    completed = []
    for record in records:
        if record.get("kind") != "transition":
            continue
        event = record.get("event")
        if event == "connected":
            controllers[record["connection"]] = record["controller"]
        session_id = record.get("session")
        if session_id is not None:
            session = sessions.setdefault(session_id, {
                "physicalMovement": False, "neutral": False, "moves": 0,
                "lastFrame": None, "boundsValid": True, "confirmation": False,
            })
            frame = record.get("frame")
            if frame:
                session["boundsValid"] &= covered_by_displays(frame, record.get("displays", []))
                if (event == "moved" and session["physicalMovement"]
                        and session["lastFrame"] is not None and frame != session["lastFrame"]):
                    session["moves"] += 1
                session["lastFrame"] = frame
            physical = (
                event == "controllerFrame" and record.get("continuous") is True
                and record.get("connection") == record.get("owner")
                and controllers.get(record.get("connection")) == controller_name
            )
            if physical:
                magnitude = math.hypot(*record.get("rightStick", [0, 0]))
                if magnitude > 0.1 and record.get("moving") is True:
                    session["physicalMovement"] = True
                if (session["moves"] and magnitude <= 0.1 and record.get("moving") is False
                        and record.get("phase") == "Active"):
                    session["neutral"] = True
                if "confirm" in record.get("buttons", []) and record.get("phase") == "Dismissing":
                    session["confirmation"] = True
        for output in record.get("outputs", []):
            if output.get("type") != "selected":
                continue
            session = sessions.get(output.get("session"), {})
            if (session.get("physicalMovement") and session.get("moves", 0) > 0
                    and session.get("neutral") and session.get("boundsValid")
                    and session.get("confirmation") and event == "dismissed"
                    and record.get("phase") == "Idle" and record.get("moving") is False):
                completed.append({"session": output["session"], "value": output["value"],
                                  "menuPath": output["menuPath"], "observedMoves": session["moves"]})
    return {"passed": bool(completed), "controller": controller_name, "completed": completed}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recording", type=Path)
    parser.add_argument("--controller", required=True, help="Exact controller name reported by macOS")
    args = parser.parse_args()
    records = [json.loads(line) for line in args.recording.read_text().splitlines() if line.strip()]
    result = verify(records, args.controller)
    print(json.dumps(result, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
