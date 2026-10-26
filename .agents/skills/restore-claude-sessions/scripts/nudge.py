"""Send the "you were resumed" message to chosen sessions, once each one is ready for input.

Usage: python3 -I nudge.py PANES.json MESSAGES.json

MESSAGES.json maps a session id to the extra text for that session ("" for
none). The base message goes first. In the extra text, {pane:<session id>}
becomes that session's new tmux pane id, so a watcher learns where its
target moved. The script waits up to 90 s per pane for the Claude input box,
types the text literally, pauses, then presses Enter. It does not judge
delivery from the screen: check.py reads the transcript instead.
"""
import json
import re
import subprocess
import sys
import time

BASE = ("This session was resumed after my laptop died, and I don't remember what this session was about. "
        "Check if anything is needed from me. If nothing is needed, continue what you were doing.")


def capture(pane):
    return subprocess.run(["tmux", "capture-pane", "-p", "-J", "-t", pane], capture_output=True, text=True).stdout


def main():
    panes = json.load(open(sys.argv[1]))
    extras = json.load(open(sys.argv[2]))
    for sid, extra in extras.items():
        pane = panes.get(sid)
        if not pane:
            print(f"{sid[:8]} no pane, not sent")
            continue
        deadline = time.time() + 90
        while "❯" not in capture(pane) and time.time() < deadline:
            time.sleep(2)
        extra = re.sub(r"\{pane:([0-9a-f-]+)\}", lambda m: panes.get(m.group(1), "UNKNOWN"), extra)
        text = BASE + (" " + extra if extra else "")
        subprocess.run(["tmux", "send-keys", "-t", pane, "-l", text], check=True)
        time.sleep(0.5)
        subprocess.run(["tmux", "send-keys", "-t", pane, "Enter"], check=True)
        print(f"{sid[:8]} sent to {pane}")


if __name__ == "__main__":
    main()
