"""Save the live tmux layout, with the Claude session in each pane, so restore.py can rebuild it.

Usage:
  python3 -I snapshot.py            take a snapshot now (skipped when nothing changed)
  python3 -I snapshot.py --list     list saved snapshots, newest first
  python3 -I snapshot.py --install  run a snapshot every 10 minutes with launchd
  python3 -I snapshot.py --uninstall

Snapshots go to ~/.cache/restore-claude-sessions/snapshots/<YYYYmmdd-HHMMSS>.json;
the newest 200 are kept. The format is the layout format of restore.py, plus
each window's tmux layout string and size, so splits come back at the same
proportions. A pane's Claude session id comes from Claude Code's process
registry (~/.claude/sessions/<pid>.json, field "tmux"), or else from the
`claude -r <id>` command line of the process in the pane.
"""
import datetime as dt
import glob
import json
import os
import re
import shutil
import subprocess
import sys

CACHE = os.path.expanduser("~/.cache/restore-claude-sessions")
SNAPS = f"{CACHE}/snapshots"
KEEP = 200
LABEL = "local.restore-claude-sessions.snapshot"
PLIST = os.path.expanduser(f"~/Library/LaunchAgents/{LABEL}.plist")
UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
SEP = "\t"
# Hooks append live state marks (✓, ✓✓, ⛔, spinners) to window names; a restore must not freeze them.
STATUS_MARKS = re.compile(r"[\s -⯿⠀-⣿\U0001f000-\U0001faff]+$")
FIELDS = ["session_name", "window_index", "window_name", "window_layout", "window_active", "window_width",
          "window_height", "pane_id", "pane_index", "pane_active", "pane_pid", "pane_current_path",
          "pane_current_command"]


def run(*args):
    return subprocess.run(args, capture_output=True, text=True)


def registry_by_pane():
    """tmux pane id -> (session id, launch dir), for running claude processes only."""
    out = {}
    for f in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
        try:
            rec = json.load(open(f))
        except (OSError, ValueError):
            continue
        pane = (rec.get("tmux") or "").rsplit(".", 1)[-1]
        comm = run("ps", "-p", str(rec.get("pid")), "-o", "comm=").stdout.strip()
        if pane.startswith("%") and os.path.basename(comm) == "claude":
            out[pane] = (rec["sessionId"], rec.get("cwd"), rec.get("name"))
    return out


def claude_under(pid, procs):
    """First claude process below pid, as (pid, args)."""
    stack = [pid]
    while stack:
        p = stack.pop()
        for child, (ppid, comm, args) in procs.items():
            if ppid != p:
                continue
            if os.path.basename(comm) == "claude":
                return child, args
            stack.append(child)
    return None


def take():
    r = run("tmux", "list-panes", "-a", "-F", SEP.join("#{%s}" % f for f in FIELDS))
    if r.returncode != 0 or not r.stdout.strip():
        return print("no tmux server, nothing to save")
    procs = {}
    for line in run("ps", "-A", "-o", "pid=,ppid=,comm=,args=").stdout.splitlines():
        parts = line.split(None, 3)
        if len(parts) >= 3:
            procs[parts[0]] = (parts[1], parts[2], parts[3] if len(parts) > 3 else "")
    reg = registry_by_pane()

    sessions = {}
    for line in r.stdout.splitlines():
        f = dict(zip(FIELDS, line.split(SEP)))
        sess = sessions.setdefault(f["session_name"], {"name": f["session_name"], "windows": {}})
        win = sess["windows"].setdefault(f["window_index"], {
            "name": STATUS_MARKS.sub("", f["window_name"]) or f["window_name"], "layout": f["window_layout"], "active": f["window_active"] == "1",
            "size": [int(f["window_width"]), int(f["window_height"])], "panes": []})
        pane = {"cwd": f["pane_current_path"], "sid": None, "command": f["pane_current_command"],
                "active": f["pane_active"] == "1"}
        found = claude_under(f["pane_pid"], procs)
        if found:
            pane["command"] = "claude"
        if f["pane_id"] in reg:
            pane["sid"], launch_dir, pane["claude_name"] = reg[f["pane_id"]]
            pane["cwd"] = launch_dir or pane["cwd"]
        elif found and "--fork-session" not in found[1]:
            # A fork gets a new id; the -r id on its command line is the parent's.
            m = re.search(rf"(?:-r|--resume)[ =]({UUID})", found[1])
            pane["sid"] = m.group(1) if m else None
        if found and not pane["sid"]:
            pane["note"] = "claude without a known session id"
        win["panes"].append(pane)

    snap_sessions = [{"name": s["name"], "windows": [s["windows"][k] for k in sorted(s["windows"], key=int)]}
                     for s in sessions.values()]
    os.makedirs(SNAPS, exist_ok=True)
    existing = sorted(glob.glob(f"{SNAPS}/*.json"))
    if existing and json.load(open(existing[-1]))["sessions"] == snap_sessions:
        return print("no change since", os.path.basename(existing[-1]))
    now = dt.datetime.now()
    path = f"{SNAPS}/{now:%Y%m%d-%H%M%S}.json"
    json.dump({"taken_at": now.isoformat(timespec="seconds"), "sessions": snap_sessions}, open(path, "w"), indent=1)
    for old in existing[:max(0, len(existing) + 1 - KEEP)]:
        os.remove(old)
    print("saved", path, summary(snap_sessions))


def summary(sessions):
    panes = [p for s in sessions for w in s["windows"] for p in w["panes"]]
    return (f"{len(sessions)} tmux sessions, {sum(len(s['windows']) for s in sessions)} windows, "
            f"{len(panes)} panes, {sum(1 for p in panes if p['sid'])} Claude sessions")


def list_snaps():
    for path in sorted(glob.glob(f"{SNAPS}/*.json"), reverse=True):
        print(os.path.basename(path), summary(json.load(open(path))["sessions"]))


def install():
    # sys.executable is a versioned Cellar path that brew upgrades remove; the PATH entries stay put.
    py = shutil.which("python3")
    tmux_bin = shutil.which("tmux")
    if not py or not tmux_bin:
        sys.exit("python3 and tmux must be on PATH")
    script = os.path.abspath(__file__)
    os.makedirs(CACHE, exist_ok=True)
    plist = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>{LABEL}</string>
  <key>ProgramArguments</key><array><string>{py}</string><string>-I</string><string>{script}</string></array>
  <key>StartInterval</key><integer>600</integer>
  <key>RunAtLoad</key><true/>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>{os.path.dirname(tmux_bin)}:{os.path.dirname(py)}:/usr/bin:/bin:/usr/sbin</string></dict>
  <key>StandardOutPath</key><string>{CACHE}/snapshot.log</string>
  <key>StandardErrorPath</key><string>{CACHE}/snapshot.log</string>
</dict></plist>
"""
    open(PLIST, "w").write(plist)
    uid = os.getuid()
    run("launchctl", "bootout", f"gui/{uid}/{LABEL}")
    r = run("launchctl", "bootstrap", f"gui/{uid}", PLIST)
    print("installed" if r.returncode == 0 else f"launchctl failed: {r.stderr.strip()}", PLIST)


def uninstall():
    run("launchctl", "bootout", f"gui/{os.getuid()}/{LABEL}")
    if os.path.exists(PLIST):
        os.remove(PLIST)
    print("removed", PLIST)


if __name__ == "__main__":
    {"--list": list_snaps, "--install": install, "--uninstall": uninstall}.get(
        sys.argv[1] if len(sys.argv) > 1 else "", take)()
