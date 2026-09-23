"""Check a recorded physical controller loss followed by a fresh successful choice."""

import argparse
import json
from pathlib import Path


def session_outputs(transitions, session):
    return [(i, output) for i, record in enumerate(transitions) for output in record.get("outputs", [])
            if output.get("session") == session]


def check_loss(transitions, start, end, connection):
    for index in range(start + 1, end):
        loss, before = transitions[index], transitions[index - 1]
        if loss.get("event") != "disconnected" or loss.get("connection") != connection:
            continue
        session = before.get("session")
        if before.get("phase") != "Active" or before.get("owner") != connection or session is None:
            continue
        movement = [r for r in transitions[start:index] if r.get("session") == session]
        physical_movement = any(r.get("event") == "controllerFrame" and r.get("connection") == connection and
                                r.get("continuous") is True and r.get("moving") is True and
                                r.get("rightStick", [0, 0]) != [0, 0] for r in movement)
        positions = {tuple(r["frame"]) for r in movement if "frame" in r}
        if not physical_movement or len(positions) < 2 or loss.get("moving") is not False:
            continue
        outcomes = session_outputs(transitions, session)
        if len(outcomes) != 1:
            continue
        completion_index, outcome = outcomes[0]
        if (index < completion_index < end and outcome.get("type") == "cancelled" and
                outcome.get("reason") == "controllerLost" and
                transitions[completion_index].get("event") == "dismissed"):
            return {"cancelledSession": session, "movingAtDisconnect": before.get("moving") is True}
    return None


def check_choice(transitions, start, end, connection):
    for index in range(start + 1, end):
        opened = transitions[index]
        session = opened.get("session")
        if not (opened.get("event") == "controllerFrame" and opened.get("connection") == connection and
                opened.get("continuous") is True and "menu" in opened.get("buttons", []) and
                opened.get("phase") == "Presenting" and opened.get("owner") == connection and session is not None):
            continue
        choices = session_outputs(transitions, session)
        if len(choices) != 1:
            continue
        chosen_index, chosen = choices[0]
        if not (index < chosen_index < end and chosen.get("type") == "selected" and
                chosen.get("value") == "red" and transitions[chosen_index].get("event") == "dismissed"):
            continue
        confirmed = any(r.get("event") == "controllerFrame" and r.get("connection") == connection and
                        r.get("continuous") is True and "confirm" in r.get("buttons", []) and
                        r.get("session") == session and r.get("selected") == "red" and
                        r.get("phase") == "Dismissing" for r in transitions[index:chosen_index])
        if confirmed:
            return session
    return None


def verify(records, controller):
    transitions = [r for r in records if r.get("kind") == "transition"]
    connections = [(i, r) for i, r in enumerate(transitions)
                   if r.get("event") == "connected" and r.get("controller") == controller]
    for position in range(1, len(connections)):
        start, previous = connections[position - 1]
        reconnect_index, reconnected = connections[position]
        end = connections[position + 1][0] if position + 1 < len(connections) else len(transitions)
        old, fresh = previous["connection"], reconnected["connection"]
        if old == fresh or reconnected.get("phase") != "Idle":
            continue
        loss = check_loss(transitions, start, reconnect_index, old)
        choice = check_choice(transitions, reconnect_index, end, fresh)
        if loss and choice is not None and choice != loss["cancelledSession"]:
            return {"passed": True, "oldConnection": old, "newConnection": fresh,
                    **loss, "selectedSession": choice, "buttonsAtReconnect": reconnected.get("buttons", []),
                    "value": "red"}
    return {"passed": False, "reason": "No complete named-controller movement, loss, reconnection, and Red choice"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recording", type=Path)
    parser.add_argument("--controller", required=True)
    args = parser.parse_args()
    records = [json.loads(line) for line in args.recording.read_text().splitlines()]
    result = verify(records, args.controller)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
