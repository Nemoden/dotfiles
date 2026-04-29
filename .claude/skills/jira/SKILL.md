---
name: jira
description: "Manage Jira issues: list, create, view, edit, transition, and comment. Use when the user asks to create a ticket/issue, list their issues, check sprint status, move a ticket to a different status, update a Jira issue, add comments, view issue details, or any Jira-related task. Also triggers on: 'create a ticket', 'my issues', 'sprint board', 'move to in progress', 'close the ticket', 'jira', 'what am I working on'."
---

# Jira

## Config

- Server: `$CC_JIRA_SERVER` env var
- Auth: basic auth — `$CC_JIRA_USER` + API token from `$CC_JIRA_TOKEN` env var
- Default project: `PROJ`
- CLI: `jira` (ankitpokhrel/jira-cli)

## When to use CLI vs REST API

Use whichever the user asks for. If no preference stated:
- **CLI** (`jira`): listing, viewing, transitioning, simple edits. Fast and sufficient.
- **REST API** (curl): creating/editing issues with rich formatting (panels, code blocks, tables). The CLI `-b` flag only supports plain text.

Read env vars once per session:
```bash
JIRA_SERVER="${CC_JIRA_SERVER:?Set CC_JIRA_SERVER env var}"
JIRA_USER="${CC_JIRA_USER:?Set CC_JIRA_USER env var}"
JIRA_TOKEN="${CC_JIRA_TOKEN:?Set CC_JIRA_TOKEN env var}"
```

## API Reference

Full OpenAPI spec: [references/swagger-v3.json](references/swagger-v3.json). Use Grep/Read to look up endpoints, parameters, schemas, and request/response formats when needed. This is the authoritative reference for all REST API calls.

### Self-healing: when an API call fails

If a REST API call returns an error indicating the endpoint has been removed, changed, or behaves differently than expected:

1. Fetch the latest spec: `curl -s "https://developer.atlassian.com/cloud/jira/platform/swagger-v3.v3.json" -o ~/.claude/skills/jira/references/swagger-v3.json`
2. Grep the new spec for the relevant endpoint to find the correct path, method, and parameters
3. Update this SKILL.md if any documented examples are now wrong
4. Then retry the call with the corrected endpoint

## Listing issues

**Always include sprint info in ticket lists.** Show active sprint name per ticket, or `(backlog)` if not in any active sprint. Never present a ticket list without this column — the user needs to know what's committed vs. backlog at a glance.

### CLI

```bash
jira issue list -a"$CC_JIRA_USER" -s"In Progress" -s"To Do"
jira sprint list --state active
jira issue list -q"project = PROJ AND status = 'In Progress' AND assignee = currentUser()"
jira issue list -q"parent = PROJ-361"
```

**Sprint column caveat:** The CLI `--columns ...,SPRINT,...` flag often returns an empty value even when the ticket is in an active sprint (happens with multi-board projects). **Do not trust CLI for sprint info — use the REST API path below.**

### REST API

**Endpoint:** `POST /rest/api/3/search/jql` (the old `GET /rest/api/3/search` has been removed).

Body: `{"jql": "...", "fields": [...], "maxResults": N, "nextPageToken": "..."}`

See `SearchAndReconcileRequestBean` in [references/swagger-v3.json](references/swagger-v3.json) for full schema.

**Sprint field id is tenant-specific.** Jira assigns custom field ids at install time — `customfield_10006` is *this tenant's* Sprint field, not a universal constant. For other Jira instances, discover the id:

```bash
curl -s -u "$CC_JIRA_USER:$CC_JIRA_TOKEN" "$CC_JIRA_SERVER/rest/api/3/field" \
  | python3 -c "import json,sys; print([f['id'] for f in json.load(sys.stdin) if f['name']=='Sprint'][0])"
```

The Sprint field value is an **array** — a ticket may have been in multiple sprints over its lifetime. Filter `state == 'active'` to get the current one; absence of any active entry → `(backlog)`.

**Listing with sprint (default pattern):**

```bash
JIRA_TOKEN="${CC_JIRA_TOKEN:?}"
curl -s -X POST "$CC_JIRA_SERVER/rest/api/3/search/jql" \
  -H "Content-Type: application/json" \
  -u "$CC_JIRA_USER:$JIRA_TOKEN" \
  -d '{"jql":"<JQL>","fields":["summary","status","customfield_10006"],"maxResults":100}' \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
for i in d.get('issues', []):
    f = i['fields']
    sprints = f.get('customfield_10006') or []
    active = [s['name'] for s in sprints if s.get('state') == 'active']
    sprint = active[0] if active else '(backlog)'
    print(f\"{i['key']}\t{f['status']['name']}\t{sprint}\t{f['summary']}\")
"
```

## Viewing issues

```bash
jira issue view PROJ-123
jira issue view PROJ-123 --raw  # Full JSON for programmatic use
```

## Creating issues

### Simple (plain text description)

```bash
jira issue create -p PROJ -t Task -P PROJ-361 --no-input \
  -s "Issue summary" \
  -b "Plain text description"
```

`-P` sets parent (epic). `-t` is issue type: `Task`, `Bug`, `Story`, `Epic`.

### Rich formatting (REST API with ADF)

Use when the issue needs panels, code blocks, bullet lists, or inline code formatting. Read [references/adf.md](references/adf.md) for the full ADF node reference before constructing the JSON.

**ADF is not markdown.** Backticks, asterisks, and `\n` inside a text node render literally. Inline code requires splitting the string into separate text nodes with a `code` mark on the code spans — see "ADF is not markdown" in the reference.

```bash
JIRA_TOKEN="${CC_JIRA_TOKEN:?Set CC_JIRA_TOKEN env var}"
curl -s -X POST "$CC_JIRA_SERVER/rest/api/3/issue" \
  -H "Content-Type: application/json" \
  -u "$CC_JIRA_USER:$JIRA_TOKEN" \
  -d '{
    "fields": {
      "project": {"key": "PROJ"},
      "parent": {"key": "PROJ-361"},
      "issuetype": {"name": "Task"},
      "summary": "Issue title",
      "description": <ADF_JSON>
    }
  }'
```

Always include a green success panel for acceptance criteria when creating task tickets. See the "Common pattern: Acceptance Criteria" section in [references/adf.md](references/adf.md).

### Content rules for ticket descriptions

- **Never reference line numbers** in code references. Lines drift as code changes — by the time someone reads the ticket the line number is wrong and misleads both humans and LLMs. Reference function/method names alongside file paths instead.
- **Do include file paths, function names, and all context** that helps the person working on the ticket. Tickets are internal — they should be as specific and helpful as possible.

## Editing issues

### Simple edits (CLI)

```bash
jira issue edit PROJ-123 -s"New summary" --no-input
jira issue edit PROJ-123 -b"New plain description" --no-input
jira issue edit PROJ-123 -a"person@email.com" --no-input
jira issue edit PROJ-123 -y"High" --no-input
```

### Rich description edit (REST API)

```bash
curl -s -X PUT "$CC_JIRA_SERVER/rest/api/3/issue/PROJ-123" \
  -H "Content-Type: application/json" \
  -u "$CC_JIRA_USER:$JIRA_TOKEN" \
  -d '{"fields": {"description": <ADF_JSON>}}'
```

## Transitioning status

```bash
jira issue move PROJ-123 "In Progress"
jira issue move PROJ-123 "Done"
jira issue move PROJ-123 "To Do"
```

To see available transitions:
```bash
jira issue move PROJ-123
```

## Comments

```bash
# Add plain text comment
jira issue comment add PROJ-123 "Comment text"

# Rich comment (REST API)
curl -s -X POST "$CC_JIRA_SERVER/rest/api/3/issue/PROJ-123/comment" \
  -H "Content-Type: application/json" \
  -u "$CC_JIRA_USER:$JIRA_TOKEN" \
  -d '{"body": <ADF_JSON>}'
```

## Linking issues

```bash
jira issue link PROJ-123 PROJ-456 "Blocks"
```

### Multi-ticket workflows with dependencies

When creating **more than one** related ticket where execution order matters (one blocks another, one depends on another), do it in **two passes**, not one:

1. **Pass 1 — create all tickets first.** Capture the returned issue keys.
2. **Pass 2 — link them and, if needed, edit descriptions to reference each other by key.**

Why: at creation time you don't yet know the keys of the other tickets, so descriptions cannot reference them concretely. Embedding the dependency only in prose (e.g. "do this after the other ticket lands") leaves no machine-readable signal — Jira boards, blocked-by filters, and assignees won't see the relationship. Use `jira issue link <blocker> <blocked> "Blocks"` so the dependency is structured.

Example:
```bash
# Pass 1: create both
A=$(jira issue create -p PROJ -t Task --no-input -s "Modernize service X" -b "..." | grep -oE 'PROJ-[0-9]+')
B=$(jira issue create -p PROJ -t Task --no-input -s "Rotate secret in service X" -b "..." | grep -oE 'PROJ-[0-9]+')

# Pass 2: link (A blocks B) and optionally edit B's description to reference A
jira issue link "$A" "$B" "Blocks"
```

## Opening in browser

```bash
jira open PROJ-123
```

## ADF reference

For rich formatting (panels, code, tables, marks), read [references/adf.md](references/adf.md). Key patterns:
- **Acceptance criteria**: green `success` panel with bold header + bullet list
- **Inline code**: text node with `{"type": "code"}` mark
- **Bold**: text node with `{"type": "strong"}` mark
