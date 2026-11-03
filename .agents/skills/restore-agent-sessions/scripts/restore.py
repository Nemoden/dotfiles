"""Build tmux sessions, windows and panes from a snapshot or layout file, and resume the agent session in each pane.

Usage: python3 -I restore.py SOURCE PANES_OUT.json [--dry-run] [--only a,b] [--skip a,b]

SOURCE is a file from snapshot.py, a layout file written by hand, or "auto":
the newest snapshot taken before the last boot (the layout the crash killed),
or the newest snapshot when none is that old. --only and --skip take tmux
session names.

Format (snapshot.py writes all keys; a hand-written layout needs only name, panes, sid, cwd):
  {"sessions": [{"name": "my-project", "windows": [
      {"name": "main", "layout": "<tmux layout string>", "size": [188, 36], "active": true,
       "panes": [{"sid": "<session id>", "cwd": "/start/dir", "command": "claude"},
                 {"sid": null, "cwd": "/dir", "command": "nvim", "split": "25%"}]}]}]}

A pane with a sid resumes it in cwd: `claude -r <sid>`, or with "command"
"codex" `codex resume <sid>`, or with "command" "pi" `pi --session <session_file>`.
A pane without a sid gets a shell in cwd, and its old command only shows in the
plan. "split" puts a pane to the right of the previous one at that width;
"layout" puts all panes back at their saved geometry. A tmux session that
exists already gets the windows appended, and its current windows stay as they
are. A session with a live process is left out, because two processes on one
transcript corrupt it.
PANES_OUT.json maps each session id to its new tmux pane id (%N).
"""
import glob
import json
import os
import shlex
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan import boot_time, live_session_ids  # noqa: E402
from snapshot import SNAPS, STATUS_MARKS, read_layout  # noqa: E402

# Each agent process loads its whole transcript at start; dozens at once stall the machine.
STAGGER_S = 3


def resume_cmd(pane):
    """The command that resumes the pane's session; a hand-written layout has no "command", so it means claude."""
    sid = pane.get("sid")
    if not sid:
        return None
    if pane.get("command") == "codex":
        return f"codex resume {sid}"
    if pane.get("command") == "pi":
        return f"pi --session {shlex.quote(pane.get('session_file') or sid)}"
    return f"claude -r {sid}"


def tmux(*args):
    return subprocess.run(["tmux", *args], check=True, capture_output=True, text=True).stdout.strip()


def tmux_windows():
    """Live tmux session name -> its window names, without status marks."""
    r = subprocess.run(["tmux", "list-windows", "-a", "-F", "#{session_name}\t#{window_name}"],
                       capture_output=True, text=True)
    out = {}
    for line in r.stdout.splitlines() if r.returncode == 0 else []:
        s, w = line.split("\t", 1)
        out.setdefault(s, set()).add(STATUS_MARKS.sub("", w) or w)
    return out


def pick_source(arg):
    if arg != "auto":
        return arg
    snaps = sorted(glob.glob(f"{SNAPS}/*.json"))
    if not snaps:
        sys.exit("no snapshots; build a layout from transcripts with scan.py instead")
    boot = boot_time() or 0
    before = [p for p in snaps if os.path.getmtime(p) < boot]
    return (before or snaps)[-1]


def option(name):
    if name in sys.argv:
        return set(sys.argv[sys.argv.index(name) + 1].split(","))
    return None


def main():
    source = pick_source(sys.argv[1])
    out_path = sys.argv[2]
    dry = "--dry-run" in sys.argv
    only, skip = option("--only"), option("--skip") or set()
    data = json.load(open(source))
    print(f"source: {source}" + (f" (taken {data['taken_at']})" if "taken_at" in data else ""))

    # Codex and pi keep no process registry, so a session open in a live pane counts as live.
    live = live_session_ids() | {p["sid"] for s in read_layout() or [] for w in s["windows"] for p in w["panes"] if p["sid"]}
    live_windows = tmux_windows()
    existing = set(live_windows)
    panes, notes, launched = {}, [], 0

    for sess in data["sessions"]:
        name = sess["name"]
        if (only and name not in only) or name in skip:
            continue
        appended = name in existing
        for win in sess["windows"]:
            if win["name"] in live_windows.get(name, ()):
                notes.append(f"{name}:{win['name']} window exists already, left out")
                continue
            wanted = []
            for pane in win["panes"]:
                sid = pane.get("sid")
                if sid and sid in live:
                    notes.append(f"{name}:{win['name']} {sid[:8]} is live already, left out")
                elif not os.path.isdir(pane["cwd"]):
                    notes.append(f"{name}:{win['name']} {(sid or '-')[:8]} dir missing: {pane['cwd']}")
                else:
                    wanted.append(pane)
            if not wanted:
                continue
            first = prev = None
            for i, pane in enumerate(wanted):
                sid, cwd = pane.get("sid"), pane["cwd"]
                size = ["-x", str(win["size"][0]), "-y", str(win["size"][1])] if win.get("size") else []
                fmt = ["-P", "-F", "#{pane_id}"]
                if i == 0 and name not in existing:
                    cmd = ["new-session", "-d", "-s", name, "-n", win["name"], "-c", cwd, *size, *fmt]
                    existing.add(name)
                elif i == 0:
                    cmd = ["new-window", "-d", "-t", f"{name}:", "-n", win["name"], "-c", cwd, *fmt]
                else:
                    cmd = ["split-window", "-d", "-h", "-l", pane.get("split", "50%"), "-t", prev, "-c", cwd, *fmt]
                resume = resume_cmd(pane)
                what = resume or f"shell (was: {pane.get('command', '?')})"
                print(("DRY " if dry else "") + f"{name}:{win['name']}{' (appended)' if appended else ''}  {cwd}  -> {what}")
                if dry:
                    prev = first = first or "<pane>"
                    launched += bool(sid)
                    continue
                pid = tmux(*cmd)
                first = first or pid
                prev = pid
                if sid:
                    tmux("send-keys", "-t", pid, "-l", resume)
                    tmux("send-keys", "-t", pid, "Enter")
                    panes[sid] = pid
                    launched += 1
                    time.sleep(STAGGER_S)
            if dry:
                continue
            if win.get("layout") and len(wanted) == len(win["panes"]) and len(wanted) > 1:
                r = subprocess.run(["tmux", "select-layout", "-t", first, win["layout"]], capture_output=True, text=True)
                if r.returncode:
                    notes.append(f"{name}:{win['name']} saved geometry not applied: {r.stderr.strip()}")
            if win.get("active") and not appended:
                tmux("select-window", "-t", first)

    if not dry:
        json.dump(panes, open(out_path, "w"), indent=1)
    print(f"{'would resume' if dry else 'resumed'} {launched} agent sessions")
    for n in notes:
        print("  NOTE", n)


if __name__ == "__main__":
    main()
