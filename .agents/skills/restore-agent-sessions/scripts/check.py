"""Report, from each transcript, whether a session got the resume message and what it replied.

Usage: python3 -I check.py SID [SID ...] [--full]

For each session: got = the message is in the transcript as a user entry;
done = the turn after it finished; then the end of the last reply (all of it
with --full). The screen is not a reliable signal: a sent message and an
unsent draft both show next to the prompt marker.
"""
import glob
import json
import os
import re
import sys

MARK = "resumed after my laptop died"


def main():
    full = "--full" in sys.argv
    for sid in [a for a in sys.argv[1:] if not a.startswith("--")]:
        f = [p for p in glob.glob(os.path.expanduser(f"~/.claude/projects/*/{sid}*.jsonl"))][0]
        got = done = False
        last = ""
        for line in open(f, errors="ignore"):
            if MARK in line and '"type":"user"' in line:
                got, done, last = True, False, ""  # the newest message wins over older restores
                continue
            if not got:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if d.get("type") == "assistant":
                text = " ".join(i.get("text", "") for i in d["message"].get("content", [])
                                if isinstance(i, dict) and i.get("type") == "text").strip()
                if text:
                    last = text
            if d.get("type") == "system" and d.get("subtype") in ("turn_duration", "stop_hook_summary"):
                done = True
        last = re.sub(r"\s+", " ", last)
        print(f"{sid[:8]} got={got} done={done} :: {last if full else last[-600:]}\n")


if __name__ == "__main__":
    main()
