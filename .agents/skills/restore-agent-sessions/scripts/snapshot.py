"""Save the live tmux layout, with the agent session in each pane, so restore.py can rebuild it.

Usage:
  python3 -I snapshot.py            take a snapshot now (skipped when nothing changed)
  python3 -I snapshot.py --list     list saved snapshots, newest first
  python3 -I snapshot.py --install  run a snapshot every 10 minutes with launchd, and add the thread id to Codex's title
  python3 -I snapshot.py --uninstall

Snapshots go to ~/.cache/restore-agent-sessions/snapshots/<YYYYmmdd-HHMMSS>.json;
the newest 200 are kept. The format is the layout format of restore.py, plus
each window's tmux layout string and size, so splits come back at the same
proportions. A pane that runs Claude Code, Codex or pi records its tool in
"command" and the id of its conversation in "sid":

  claude  Claude Code's process registry (~/.claude/sessions/<pid>.json, field
          "tmux"), or else the `claude -r <id>` command line.
  codex   The tmux pane title: --install adds "thread-id" to Codex's terminal
          title. Codex cuts the id to 29 characters, which is enough to find the
          one rollout file that holds the full id. Or else the `codex resume <id>`
          command line. A Codex hook cannot tell its pane: hooks run in a server
          process that all Codex windows share, with the environment of the
          window that started it.
  pi      The record that pi-extension.ts (linked into ~/.pi/agent/extensions/)
          writes on each session start, or else the `pi --session <file>`
          command line. A pi pane also records "session_file".
"""
import datetime as dt
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tomllib

CACHE = os.path.expanduser("~/.cache/restore-agent-sessions")
SNAPS = f"{CACHE}/snapshots"
REGISTRY = f"{CACHE}/registry"
KEEP = 200
LABEL = "local.restore-agent-sessions.snapshot"
OLD_LABEL = "local.restore-claude-sessions.snapshot"
PLIST = os.path.expanduser(f"~/Library/LaunchAgents/{LABEL}.plist")
CODEX_CONFIG = os.path.expanduser("~/.codex/config.toml")
CODEX_SESSIONS = os.path.expanduser("~/.codex/sessions")
AGENTS = ("claude", "codex", "pi")
UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
UUID_PREFIX = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{1,12}"
SEP = "\t"
# Hooks append live state marks (\u2713, \u26d4, \u2692 plus a count, spinners) to window names; a restore must not freeze them.
# Pattern uses escapes, not literal glyphs: a literal U+2000 once became a space and the class swallowed all of ASCII.
STATUS_MARKS = re.compile(r"(?:\s*(?:\u2692\d+|[\u2000-\u2bff\u2800-\u28ff\U0001f000-\U0001faff]+))+$")
# pane_title goes last: a title may hold a tab, and the last field takes the rest of the line.
FIELDS = ["session_name", "window_index", "window_name", "window_layout", "window_active", "window_width",
          "window_height", "pane_id", "pane_index", "pane_active", "pane_pid", "pane_current_path",
          "pane_current_command", "pane_title"]


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


def pi_registry():
    """tmux pane id -> (session id, session file), from the records of running pi processes."""
    out = {}
    for f in glob.glob(f"{REGISTRY}/pi-*.json"):
        try:
            rec = json.load(open(f))
        except (OSError, ValueError):
            continue
        comm = run("ps", "-p", str(rec.get("pid")), "-o", "comm=").stdout.strip()
        if os.path.basename(comm) == "pi":
            out[rec["pane"]] = (rec["sessionId"], rec["file"])
        elif not comm:
            os.remove(f)  # left by a pi that crashed or died with the machine
    return out


def agent_under(pid, procs):
    """First Claude Code, Codex or pi process below pid, as (tool, args)."""
    stack = [pid]
    while stack:
        p = stack.pop()
        for child, (ppid, comm, args) in procs.items():
            if ppid != p:
                continue
            if os.path.basename(comm) in AGENTS:
                return os.path.basename(comm), args
            stack.append(child)
    return None


def codex_thread(title):
    """Full Codex thread id from the cut id in a pane title, when exactly one rollout file matches it."""
    m = re.search(UUID_PREFIX, title)
    if not m:
        return None
    files = glob.glob(f"{CODEX_SESSIONS}/*/*/*/rollout-*{m.group(0)}*.jsonl")
    return re.search(UUID, os.path.basename(files[0])).group(0) if len(files) == 1 else None


def read_layout():
    """The live tmux sessions in the snapshot format, or None when no tmux server runs."""
    r = run("tmux", "list-panes", "-a", "-F", SEP.join("#{%s}" % f for f in FIELDS))
    if r.returncode != 0 or not r.stdout.strip():
        return None
    procs = {}
    for line in run("ps", "-A", "-o", "pid=,ppid=,comm=,args=").stdout.splitlines():
        parts = line.split(None, 3)
        if len(parts) >= 3:
            procs[parts[0]] = (parts[1], parts[2], parts[3] if len(parts) > 3 else "")
    reg, pi_reg = registry_by_pane(), pi_registry()

    sessions = {}
    for line in r.stdout.splitlines():
        f = dict(zip(FIELDS, line.split(SEP, len(FIELDS) - 1)))
        sess = sessions.setdefault(f["session_name"], {"name": f["session_name"], "windows": {}})
        win = sess["windows"].setdefault(f["window_index"], {
            "name": STATUS_MARKS.sub("", f["window_name"]) or f["window_name"], "layout": f["window_layout"], "active": f["window_active"] == "1",
            "size": [int(f["window_width"]), int(f["window_height"])], "panes": []})
        pane = {"cwd": f["pane_current_path"], "sid": None, "command": f["pane_current_command"],
                "active": f["pane_active"] == "1"}
        tool, args = agent_under(f["pane_pid"], procs) or (None, "")
        if tool:
            pane["command"] = tool
        if f["pane_id"] in reg:
            pane["sid"], launch_dir, pane["claude_name"] = reg[f["pane_id"]]
            pane["cwd"] = launch_dir or pane["cwd"]
        elif tool == "claude" and "--fork-session" not in args:
            # A fork gets a new id; the -r id on its command line is the parent's.
            m = re.search(rf"(?:-r|--resume)[ =]({UUID})", args)
            pane["sid"] = m.group(1) if m else None
        elif tool == "codex":
            # The title goes first: after /new or /resume inside Codex, the command line is out of date.
            m = re.search(rf"resume\s+({UUID})", args)
            pane["sid"] = codex_thread(f["pane_title"]) or (m.group(1) if m else None)
        elif tool == "pi" and f["pane_id"] in pi_reg:
            pane["sid"], pane["session_file"] = pi_reg[f["pane_id"]]
        elif tool == "pi":
            m = re.search(rf"--session[ =](\S*({UUID})\S*\.jsonl)", args)
            if m:
                pane["sid"], pane["session_file"] = m.group(2), m.group(1)
        if tool and not pane["sid"]:
            pane["note"] = f"{tool} without a known session id"
        win["panes"].append(pane)

    return [{"name": s["name"], "windows": [s["windows"][k] for k in sorted(s["windows"], key=int)]}
            for s in sessions.values()]


def take():
    snap_sessions = read_layout()
    if snap_sessions is None:
        return print("no tmux server, nothing to save")
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
            f"{len(panes)} panes, {sum(1 for p in panes if p['sid'])} agent sessions")


def list_snaps():
    for path in sorted(glob.glob(f"{SNAPS}/*.json"), reverse=True):
        print(os.path.basename(path), summary(json.load(open(path))["sessions"]))


def codex_title():
    """Add "thread-id" to Codex's terminal title, so tmux holds each Codex pane's thread id in the pane title."""
    if not os.path.exists(CODEX_CONFIG):
        return "no ~/.codex/config.toml, Codex title left as it is"
    text = open(CODEX_CONFIG).read()
    if '"thread-id"' in text:
        return "Codex title has thread-id already"
    m = re.search(r"^terminal_title\s*=\s*\[([^\]]*)", text, re.M)
    if m:
        items = m.group(1).rstrip().rstrip(",")
        new = text[:m.start(1)] + (f'{items}, "thread-id"' if items.strip() else '"thread-id"') + text[m.end(1):]
    else:
        line = 'terminal_title = ["activity", "project-name", "thread-id"]\n'
        tui = re.search(r"^\[tui\]\s*\n", text, re.M)
        new = text[:tui.end()] + line + text[tui.end():] if tui else text.rstrip("\n") + "\n\n[tui]\n" + line
    tomllib.loads(new)
    open(CODEX_CONFIG, "w").write(new)
    return "added thread-id to the Codex title in ~/.codex/config.toml; Codex windows opened before now do not show it"


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
    uid = os.getuid()
    # The skill was called restore-claude-sessions; its job would run a script that no longer exists.
    run("launchctl", "bootout", f"gui/{uid}/{OLD_LABEL}")
    old_plist = PLIST.replace(LABEL, OLD_LABEL)
    if os.path.exists(old_plist):
        os.remove(old_plist)
    open(PLIST, "w").write(plist)
    run("launchctl", "bootout", f"gui/{uid}/{LABEL}")
    r = run("launchctl", "bootstrap", f"gui/{uid}", PLIST)
    print("installed" if r.returncode == 0 else f"launchctl failed: {r.stderr.strip()}", PLIST)
    print(codex_title())


def uninstall():
    run("launchctl", "bootout", f"gui/{os.getuid()}/{LABEL}")
    if os.path.exists(PLIST):
        os.remove(PLIST)
    print("removed", PLIST)


if __name__ == "__main__":
    {"--list": list_snaps, "--install": install, "--uninstall": uninstall}.get(
        sys.argv[1] if len(sys.argv) > 1 else "", take)()
