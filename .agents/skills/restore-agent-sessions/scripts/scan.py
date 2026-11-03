"""List Claude Code sessions that were alive before a crash or reboot.

Usage: python3 -I scan.py [--days N] [--min-prompts N] [--tails DIR] [--json OUT]

A candidate is a top-level session (not a subagent) whose last entry is at
most N days old and that has at least N prompts typed by a human. For each
one it prints: id, last activity, prompts typed, start dir (where `claude -r`
finds it), last dir, branch, name, and the last prompt. With --tails it
writes the last 20 exchanges of each candidate to DIR/<id>.txt for summary.
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import subprocess

PROJECTS = os.path.expanduser("~/.claude/projects")
REGISTRY = os.path.expanduser("~/.claude/sessions")
SKIP_SLASH = {"/exit", "/clear", "/model", "/fast", "/effort", "/login", "/chrome", "/resume"}


def prompt_kind(text):
    if "teammate-message" in text or "<agent-message" in text:
        return "agent"
    if text.startswith("This session is being continued"):
        return "compact"
    if text.startswith("[Request interrupted"):
        return "interrupt"
    if re.search(r"<(local-command|system-reminder|task-notification)", text) and "<command-args>" not in text:
        return "system"
    if text.startswith("Base directory for this skill"):
        return "system"
    if "<command-name>" in text:
        return "slash"
    return "human"


def user_text(entry):
    content = entry.get("message", {}).get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        if any(isinstance(i, dict) and i.get("type") == "tool_result" for i in content):
            return None
        return " ".join(i.get("text", "") for i in content if isinstance(i, dict) and i.get("type") == "text")
    return None


def live_session_ids():
    """Ids of sessions with a running claude process, from Claude Code's own registry.

    A registry file can outlive its process (crash, reboot), and the OS reuses
    pids, so the pid must still belong to a process named claude.
    """
    live = set()
    for f in glob.glob(f"{REGISTRY}/*.json"):
        try:
            rec = json.load(open(f))
            cmd = subprocess.run(["ps", "-p", str(rec["pid"]), "-o", "comm="], capture_output=True, text=True).stdout
            if os.path.basename(cmd.strip()) == "claude":
                live.add(rec["sessionId"])
        except (OSError, ValueError, KeyError):
            pass
    return live


def boot_time():
    out = subprocess.run(["sysctl", "-n", "kern.boottime"], capture_output=True, text=True).stdout
    m = re.search(r"sec = (\d+)", out)
    return int(m.group(1)) if m else None


def open_at_crash(paths, boot, min_burst=5):
    """Sessions that had a running claude process before the reboot.

    Some events make every running claude process append to its transcript
    in the same second. The newest such burst before boot lists the open
    sessions. Any transcript written after that burst, and before boot,
    was open too.
    """
    before = sorted((os.path.getmtime(p), p) for p in paths if boot is None or os.path.getmtime(p) < boot)
    burst_end, burst = None, []
    for i in range(len(before) - 1, -1, -1):
        t = before[i][0]
        group = [p for m, p in before if t - 2 <= m <= t]
        if len(group) >= min_burst:
            burst_end, burst = t, group
            break
    if burst_end is None:
        return {}, None
    marks = {os.path.basename(p)[:-6]: "burst" for p in burst}
    for m, p in before:
        if m > burst_end:
            marks[os.path.basename(p)[:-6]] = "active"
    return marks, burst_end


def scan_file(path):
    s = dict(sid=os.path.basename(path)[:-6], start_cwd=None, last_cwd=None, branch=None, name=None,
             title=None, recap=None, entrypoint=None, last=None, human=0, slash=0, agent=0, exchanges=[])
    current = None
    for line in open(path, errors="ignore"):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if d.get("timestamp"):
            s["last"] = max(s["last"] or "", d["timestamp"])
        if d.get("cwd"):
            s["start_cwd"] = s["start_cwd"] or d["cwd"]
            s["last_cwd"] = d["cwd"]
        if d.get("gitBranch") and d["gitBranch"] != "HEAD":
            s["branch"] = d["gitBranch"]
        s["entrypoint"] = s["entrypoint"] or d.get("entrypoint")
        t = d.get("type")
        if t == "system" and d.get("subtype") == "away_summary" and isinstance(d.get("content"), str):
            s["recap"] = re.sub(r"\s+", " ", d["content"])
        if t == "ai-title":
            s["title"] = d.get("aiTitle")
        if d.get("customTitle"):
            s["name"] = d["customTitle"]
        if d.get("isSidechain") or d.get("isMeta"):
            continue
        if t == "user":
            text = user_text(d)
            if text is None:
                continue
            kind = prompt_kind(text)
            if kind == "human":
                s["human"] += 1
            elif kind == "slash":
                m = re.search(r"<command-name>(.*?)</command-name>.*?<command-args>(.*?)</command-args>", text, re.S)
                text = f"{m.group(1)} {m.group(2)}".strip() if m else ""
                if not text or text.split()[0] in SKIP_SLASH:
                    continue
                s["slash"] += 1
            elif kind == "agent":
                s["agent"] += 1
                continue
            else:
                continue
            current = {"you": re.sub(r"\s+", " ", text)[:700], "claude": ""}
            s["exchanges"].append(current)
        elif t == "assistant" and current is not None:
            content = d.get("message", {}).get("content")
            if isinstance(content, list):
                text = " ".join(i.get("text", "") for i in content if isinstance(i, dict) and i.get("type") == "text").strip()
                if text:
                    current["claude"] = re.sub(r"\s+", " ", text)[-900:]
    return s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=float, default=3)
    ap.add_argument("--min-prompts", type=int, default=3)
    ap.add_argument("--tails")
    ap.add_argument("--json")
    ap.add_argument("--exclude", nargs="*", default=[], help="session ids to leave out, e.g. the current one")
    a = ap.parse_args()

    now = dt.datetime.now(dt.timezone.utc)
    live = live_session_ids()
    paths = glob.glob(f"{PROJECTS}/*/*.jsonl")
    boot = boot_time()
    opened, burst_end = open_at_crash(paths, boot)
    if burst_end:
        fmt = lambda t: dt.datetime.fromtimestamp(t).strftime("%a %d %b %H:%M:%S")
        print(f"boot {fmt(boot)}; newest write burst {fmt(burst_end)}: {sum(v == 'burst' for v in opened.values())} sessions, "
              f"{sum(v == 'active' for v in opened.values())} more written after it\n")
    rows = []
    for path in paths:
        sid = os.path.basename(path)[:-6]
        if sid not in opened and now.timestamp() - os.path.getmtime(path) > a.days * 86400:
            continue
        s = scan_file(path)
        if not s["last"] or s["sid"] in a.exclude or any(s["sid"].startswith(x) for x in a.exclude):
            continue
        age_h = (now - dt.datetime.fromisoformat(s["last"].replace("Z", "+00:00"))).total_seconds() / 3600
        if s["entrypoint"] not in (None, "cli"):
            continue
        if sid not in opened and (age_h > a.days * 24 or s["human"] + s["slash"] < a.min_prompts):
            continue
        s["age_h"] = round(age_h, 1)
        s["live"] = s["sid"] in live
        s["open_at_crash"] = opened.get(sid)
        s["start_cwd_exists"] = bool(s["start_cwd"]) and os.path.isdir(s["start_cwd"])
        s["last_local"] = dt.datetime.fromisoformat(s["last"].replace("Z", "+00:00")).astimezone().strftime("%a %d %b %H:%M")
        rows.append(s)

    rows.sort(key=lambda r: r["age_h"])
    home = os.path.expanduser("~")
    for r in rows:
        short = lambda p: (p or "-").replace(home, "~")
        flags = ("LIVE " if r["live"] else "") + ("" if r["start_cwd_exists"] else "START-DIR-GONE ")
        flags += f"OPEN({r['open_at_crash']}) " if r["open_at_crash"] else "closed? "
        last_prompt = r["exchanges"][-1]["you"][:160] if r["exchanges"] else ""
        print(f"{r['sid']} | {r['last_local']} ({r['age_h']}h) | you={r['human']}+{r['slash']} agents={r['agent']} | {flags}"
              f"start={short(r['start_cwd'])} last={short(r['last_cwd'])} branch={r['branch']} "
              f"name={r['name']} title={r['title']}\n    last prompt: {last_prompt}")
    print(f"{len(rows)} candidates, {sum(r['live'] for r in rows)} already live")

    if a.tails:
        os.makedirs(a.tails, exist_ok=True)
        for r in rows:
            with open(f"{a.tails}/{r['sid']}.txt", "w") as fh:
                for i, e in enumerate(r["exchanges"][-20:]):
                    fh.write(f"--- {i + 1} YOU: {e['you']}\nCLAUDE(end of reply): {e['claude']}\n")
    if a.json:
        for r in rows:
            r["exchanges"] = r["exchanges"][-3:]
        json.dump(rows, open(a.json, "w"), indent=1)


if __name__ == "__main__":
    main()
