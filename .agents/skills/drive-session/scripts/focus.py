#!/usr/bin/env python3
"""Write the dynamic "Also keep: ..." line for a /compact, from a transcript.

Usage: focus.py [--model haiku] [--timeout 90] TRANSCRIPT
Prints the line, or nothing when the model finds nothing worth adding.
Exit 0 on success, 1 with the reason on stderr otherwise; the caller then
sends the fixed text alone.
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

PROMPT_FILE = Path(__file__).with_name("focus-prompt.md")
LAST_PROMPTS = 5
PROMPT_CHARS = 3000
REPLY_CHARS = 6000
MAX_LINE = 600
BLANK = "​﻿ \t\n"


def text_of(content: str | list[dict]) -> str:
    if isinstance(content, str):
        return content
    return " ".join(
        c.get("text", "") for c in content if c.get("type") == "text"
    )


def is_user_prompt(row: dict) -> bool:
    if row.get("type") != "user" or row.get("isMeta"):
        return False
    if row.get("isCompactSummary"):
        return False
    t = text_of(row["message"]["content"]).strip(BLANK)
    # command echoes and reminders start with a tag; a bare paste is a prompt
    return bool(t) and (
        not t.startswith("<") or t.startswith("<pasted_content")
    )


def excerpt(path: str) -> str:
    """The session since its last compact: summary, prompts, last reply."""
    rows = [json.loads(line) for line in open(path)]
    start = max(
        (i for i, r in enumerate(rows)
         if r.get("subtype") == "compact_boundary"),
        default=0,
    )
    rows = rows[start:]
    summaries = [
        r["content"] for r in rows if r.get("subtype") == "away_summary"
    ]
    prompts = [
        text_of(r["message"]["content"]).strip(BLANK)[:PROMPT_CHARS]
        for r in rows if is_user_prompt(r)
    ]
    replies = [
        text_of(r["message"]["content"]).strip(BLANK)
        for r in rows
        if r.get("type") == "assistant"
        and r["message"].get("model") != "<synthetic>"
    ]
    replies = [t for t in replies if len(t) > 20]
    parts = ["## Latest away summary", summaries[-1] if summaries else "-"]
    parts.append("\n## Last user prompts, oldest first")
    for p in prompts[-LAST_PROMPTS:]:
        parts += ["---", p]
    parts += ["\n## Last assistant reply",
              replies[-1][-REPLY_CHARS:] if replies else "-"]
    return "\n".join(parts)


def ask(model: str, timeout: int, text: str) -> str:
    cmd = [
        "claude", "-p", "--model", model, "--no-session-persistence",
        "--tools", "", "--settings", '{"disableAllHooks":true}',
        "--system-prompt", PROMPT_FILE.read_text(),
    ]
    # neutral cwd: no project CLAUDE.md in the prompt
    out = subprocess.run(
        cmd, input=text, capture_output=True, text=True, timeout=timeout,
        cwd=os.environ.get("TMPDIR", "/tmp"),
    )
    if out.returncode:
        raise RuntimeError(f"claude exit {out.returncode}")
    return out.stdout


def validate(raw: str) -> str:
    lines = [ln.strip() for ln in raw.splitlines() if ln.strip()]
    if not lines:
        raise ValueError("empty answer")
    line = lines[0]
    if line == "NONE":
        return ""
    if len(lines) > 1:
        raise ValueError(f"{len(lines)} lines, want 1")
    if not line.startswith("Also keep: "):
        raise ValueError("does not start with 'Also keep: '")
    if len(line) > MAX_LINE:
        raise ValueError(f"{len(line)} chars, max {MAX_LINE}")
    return line


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="haiku")
    ap.add_argument("--timeout", type=int, default=90)
    ap.add_argument("transcript")
    a = ap.parse_args()
    try:
        print(validate(ask(a.model, a.timeout, excerpt(a.transcript))))
    except Exception as e:
        print(f"{type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
