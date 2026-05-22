---
name: field-notes
description: Capture mid-session observations to revisit later — defer decisions without losing context. One file per session, appended over lifetime, survives `claude --resume`. Triggers on "take a note", "note this for later", "set aside", "park this", "field note", "side note", "remember to revisit", "make a note about this", `/field-notes [body]`, "where are my notes" / "path to field notes" (returns current session file path), "digest of field notes" / "summarise field notes" (produces digest — see Digest section).
---

# field-notes

Capture observations during a session that the user wants to set aside without acting on. Each session = one file. Append entries over the session lifetime. Survives `claude --resume` (keyed on session_id, not PID).

## Storage

**Scope:** per-session, one file per session.

**Path resolution:**

Use the **session's logical cwd** (the directory where Claude was launched), NOT `$PWD`. The Bash subprocess `pwd` can drift if hooks or tools `cd` elsewhere; session cwd is stable.

Source of truth: `.cwd` field in `~/.claude/sessions/{pid}.json` (same file used for session_id lookup).

1. If session cwd is inside a git repo → `<git-root>/.claude/field-notes/` (run `git -C "$session_cwd" rev-parse --show-toplevel`)
2. Else → `~/.claude/field-notes/`

**Filename:** `{YYYY-MM-DD-HHMMSS}-{slug}-{sid8}.md`
- `YYYY-MM-DD-HHMMSS` = timestamp of first note for this session (seconds precision)
- `slug` = kebab-case from first note's topic (set once, never updated)
- `sid8` = first 8 chars of Claude session_id (stable across `--resume`)

**Session ID lookup:**
```bash
ppid=$PPID
session_file="$HOME/.claude/sessions/${ppid}.json"
if [ ! -f "$session_file" ]; then
    # walk parent chain until we find a claude process
    pid=$PPID
    while [ -n "$pid" ] && [ "$pid" != "1" ]; do
        if [ "$(ps -p $pid -o comm= 2>/dev/null | xargs basename)" = "claude" ]; then
            session_file="$HOME/.claude/sessions/${pid}.json"
            break
        fi
        pid=$(ps -p $pid -o ppid= 2>/dev/null | tr -d ' ')
    done
fi
session_id=$(jq -r .sessionId "$session_file")
session_cwd=$(jq -r .cwd "$session_file")
short_sid="${session_id:0:8}"

# Resolve notes dir from session_cwd, NOT $PWD
git_root=$(git -C "$session_cwd" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$git_root" ]; then
    notes_dir="$git_root/.claude/field-notes"
else
    notes_dir="$HOME/.claude/field-notes"
fi
```

**Find existing session file:**
```bash
notes_dir="<git-root>/.claude/field-notes"  # or ~/.claude/field-notes
existing=$(ls "$notes_dir"/*"-${short_sid}.md" 2>/dev/null | head -1)
```

If `existing` non-empty → append to it. Else → create new.

## File format

### Header (written once on file creation)

```markdown
# Field notes — session {YYYY-MM-DD HH:MM}

**Session:** {short_sid}
**Started:** {YYYY-MM-DD HH:MM}
**cwd:** {session_cwd}  *(session's logical cwd, from session JSON, not subprocess pwd)*

**About this session:** {1-2 sentence description of what session was about, derived from conversation context at time of first note}

---
```

The "About this session" line is written once on first note. Never updated by later notes.

### Entry format (each note)

```markdown
## {HH:MM} — {optional title}

{body — freeform prose OR structured fields, whichever fits}
```

Optional structured fields (include only those known from conversation; never invent):

- **Context:** what was being discussed when noted
- **Observation:** the thing noticed
- **Hypothesis / why deferred:** why not acting on it now
- **Action:** what to do later
- **Files / symbols:** related code (function names, not line numbers)

Minimal note (one line):
```markdown
## 14:32

FE sends whole matter dict to download/create. Maybe intentional. Revisit.
```

Full note (when context-rich):
```markdown
## 14:32 — matter dict payload spike

**Context:** discussing download/create endpoint, firm_id trust boundary.
**Observation:** FE submits whole matter dict; only matter_id strictly needed.
**Hypothesis / why deferred:** likely intentional — document mirrors on-screen
matter state; may also save L2L calls by avoiding extra DB fetch.
**Action:** raise SPIKE — investigate intent, decide if FE can be freed
to send only matter_id + required fields.
```

Rule: fill what's known from conversation, skip what isn't. No placeholders like "TBD" or "N/A".

## Note composition

Default: **Claude composes from conversation context.** When user says "take a note" or similar, look back at recent turns to extract context, observation, action.

Fallback: **verbatim.** If user supplies body explicitly (e.g. `/field-notes <text>` or "take a note: <text>"), write that as-is without re-summarizing.

Never invent facts. Only contextualize from what's actually in conversation.

## Response after writing

After append/create, reply terse:
```
noted: {1-line summary} → {relative-or-absolute path}
```

Example: `noted: matter dict payload spike → .claude/field-notes/2026-05-20-143052-matter-payload-7b628481.md`

Then continue with whatever the user actually asked next.

## Path query

When user asks "where are my notes" / "path to field notes" / similar:
- Look up session_id (see above).
- Find `*-{short_sid}.md` in the notes dir.
- Reply: `{path}` — full path, nothing else if no file yet say `no notes yet for this session`.

## Digest

When user asks for digest, default = **current session**. Other scopes when user qualifies:

| Phrase | Scope |
|---|---|
| "digest" / "digest of this session" / "digest of my notes" | current session file only |
| "digest of today" | all files in notes dir dated today (any session) |
| "digest of all" / "digest all field notes" | all files in notes dir |
| "digest of {date}" | all files in notes dir matching that date |

Output format: bullet list, one bullet per note entry, format `{HH:MM} — {title or first-line} ({1-line takeaway})`. Group by file if multi-file scope.

## Slug generation

From first note's topic. Rules:
- lowercase
- spaces → `-`
- keep alphanumerics + `-`
- max 40 chars
- strip trailing `-`

Examples:
- "matter dict payload spike" → `matter-dict-payload-spike`
- "Take a note about firm_id trust" → `firm-id-trust`

## Edge cases

- **No git repo + no `~/.claude/field-notes/`:** create dir, proceed.
- **Session ID file missing or unreadable:** fall back to `pid{PPID}` as session id (degraded but functional). Log nothing — silent fallback.
- **Two notes within same second on first invoke:** filename includes seconds → still distinct unless literal same second AND same slug. Practically zero.
- **User says "scratch that" right after a note:** out of scope v1. Tell user to edit file manually.

## Implementation notes (for me, Claude)

- Use `Bash` to compute paths and session id; use `Write`/`Edit` for the file itself.
- Always `mkdir -p` the notes dir before writing.
- When appending, `Read` the file first, then `Edit` to add the new entry at the end (above any final newline). Do not overwrite.
- Date/time: `date '+%Y-%m-%d-%H%M%S'` for filename, `date '+%H:%M'` for entry header.
