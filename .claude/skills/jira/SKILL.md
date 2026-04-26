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

### CLI

```bash
jira issue list -a"$CC_JIRA_USER" -s"In Progress" -s"To Do"
jira sprint list --state active
jira issue list -q"project = PROJ AND status = 'In Progress' AND assignee = currentUser()"
jira issue list -q"parent = PROJ-361"
```

### REST API

**Endpoint:** `POST /rest/api/3/search/jql` (the old `GET /rest/api/3/search` has been removed).

Body: `{"jql": "...", "fields": [...], "maxResults": N, "nextPageToken": "..."}`

See `SearchAndReconcileRequestBean` in [references/swagger-v3.json](references/swagger-v3.json) for full schema.

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

## Opening in browser

```bash
jira open PROJ-123
```

## ADF reference

For rich formatting (panels, code, tables, marks), read [references/adf.md](references/adf.md). Key patterns:
- **Acceptance criteria**: green `success` panel with bold header + bullet list
- **Inline code**: text node with `{"type": "code"}` mark
- **Bold**: text node with `{"type": "strong"}` mark
