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

### Pre-flight: ALWAYS ask about sprint placement

Before creating any ticket, ask the user which sprint to add it to (or backlog). Do not create a ticket and only afterwards ask "want me to move it into sprint X?" — the prompt belongs before the API call.

Default options to offer:
- Current active sprint (look it up with `jira sprint list --state active`, show name + number)
- Next sprint, if one exists in `--state future`
- Backlog (no sprint)

Skip the question only if the user explicitly said "create in backlog" / "add to sprint N" in their request. If they said "create a ticket" with no sprint hint, ask.

To set sprint at create time, use REST API with `customfield_10006` (this tenant's Sprint id — see "Listing issues" for discovery on other tenants):

```bash
curl -s -X POST -u "$CC_JIRA_USER:$CC_JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  "$CC_JIRA_SERVER/rest/api/3/issue" \
  -d '{"fields": {"project": {"key": "PROJ"}, "issuetype": {"name": "Task"}, "summary": "...", "customfield_10006": <sprint_id>, ...}}'
```

To add an existing ticket to a sprint:

```bash
curl -s -X POST -u "$CC_JIRA_USER:$CC_JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  "$CC_JIRA_SERVER/rest/agile/1.0/sprint/<sprint_id>/issue" \
  -d '{"issues": ["PROJ-123"]}'
```

### Hierarchy rules (verified empirically; tenant-specific)

Jira projects enforce a parent-child hierarchy per issue type. In this tenant:

| Child issuetype | Allowed parent | Notes |
|---|---|---|
| `Epic` | (none / org-level) | Top-level grouping |
| `Task`, `Story`, `Bug` | `Epic` only | Cannot parent under another Task |
| `Subtask` | `Task`, `Story`, `Bug` | The only issuetype that can sit under a non-Epic |

**Trying to set `parent` to a Task on a new `Task` returns:**
```
{"errors":{"parentId":"Given parent work item does not belong to appropriate hierarchy."}}
```

**So:** if you want a child under an existing Task (e.g. splitting a too-broad ticket into pieces), use `issuetype: Subtask`. Use `Task` only when the parent is an Epic.

### Simple (plain text description)

```bash
# Task under an Epic
jira issue create -p PROJ -t Task -P PROJ-361 --no-input \
  -s "Issue summary" \
  -b "Plain text description"

# Subtask under a Task (CLI does not always accept -t Subtask cleanly;
# REST API is more reliable for subtasks — see below)
```

`-P` sets parent. `-t` is issue type: `Task`, `Bug`, `Story`, `Epic`, `Subtask`.

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
- **Never reference local-machine file paths** (e.g. `~/tmp/...`, `/Users/<you>/...`, `/private/tmp/...`). Tickets are read by other engineers and future LLMs who don't have your filesystem. If a local draft or scratch file contains context that matters, **embed the context into the ticket itself** — regurgitate the relevant facts in prose. Tickets may freely cross-reference other Jira tickets (Jira keys), Confluence pages, GitHub PRs/commits, repo paths (relative to repo root), and public URLs — but not anything that only exists on the author's workstation. A ticket must be readable cold without access to any local artifact.
- **Self-contained ≠ no refs.** Self-contained = *ticket + refs = complete*. Cite refs as original inputs; synthesise load-bearing facts inline so the body alone conveys the issue. Refs serve as evidence, not the missing half.
- **No conversation leakage.** Ban "we discussed", "this chat", "as agreed earlier". Ticket must read cold.
- **Include** file paths, function names, identifiers — anything the assignee actually needs.

### Refs / Sources section

Dedicated **Sources** section (bottom of description). One ref per line, each with a one-line description of *what it shows*.

First-class ref types (alongside Jira/Confluence/git):

- Observability — link the exact view (trace, span, log query). Include timestamp + request id in cite text so it's reproducible if the URL rots.
- Chat permalinks — link the thread, not the channel.
- Dashboards, vendor API docs.

Rule: load-bearing fact → synthesise inline, ref = evidence. Supporting detail (full trace tree, full chat) → leave in ref.

Capture in prose anything that ages out: log retention, dashboard rolling windows, thread scroll-off.

### Code excerpts

Paste real code whenever it's more useful than prose. Examples: the offending lines (bug evidence), entry-point signature so the assignee knows where to start, call-chain hop that's non-obvious, data shape the ticket depends on, comment that itself reveals a misconception.

- Real code, never pseudocode.
- Preserve original comments — author's wrong comment IS evidence.
- Cite by function name + repo-relative path. No line numbers.
- Small. One function/block/signature. Hundreds of lines = prose belongs there instead.
- ADF `codeBlock` node for multi-line.
- Excerpts illustrate; they don't prescribe the fix.

### Parent linkage

User names parent up-front → set at create-time (`"parent": {"key": "PROJ-NNN"}`). Not after — orphans the ticket on boards for a window. No parent named + plausibly belongs under epic → ask, don't pick.

### Ticket calibration

Tickets should be terse enough that agents aren't spoon-fed, detailed enough that load-bearing decisions aren't lost. Agents picking up a ticket are competent — they don't need to be told which directories to grep or which command flags to use. They DO need to be told the decisions you've already made and the conventions they couldn't infer.

Before writing each section of a ticket, ask:

- **"If I omit this, would a competent agent still arrive at the right answer?"** If yes → omit it.
- **"Is this a decision that changes the outcome, or is it an implementation detail?"** Decisions stay; details go.
- **"Am I picking the agent's tools, their file paths, or their directory layout?"** If yes → remove. Agents are not stupid.

**Strong opinion IS warranted when:**

- The pattern is a repo convention an agent wouldn't invent. Cite a canonical reference (file + symbol name), not a how-to walkthrough.
- The wiring is easy to forget and fails late: config plumbing, IAM/permissions, packaging includes, env vars, build steps.
- A default value links to other in-flight work (cross-ticket dependency that affects how this ticket should be left).
- Phase ordering matters: discovery before fix, audit before delete, migrate before remove.
- A scope boundary prevents scope creep. State "Out of scope" only when a reasonable reader would assume it's in scope.

**Strong opinion is NOT warranted when:**

- Telling agents which directories to grep or which CLI flags to use.
- Prescribing the file path or filename of intermediate artifacts the agent will produce.
- Spelling out matrix column shapes / report formats when the goal is clear.
- Walking through obvious steps ("open the file, then find the function, then...").
- Listing precedent links the agent would naturally find by following the canonical reference you already cited.

### Title calibration

Same heuristic for titles. A title that prescribes an outcome before discovery is done is wrong when the work itself starts with *"should we even do this?"*. Hedge with phrasing like "if warranted", or name the goal rather than the means.

### Anti-patterns

Generic before/after pairs. Domain placeholders only (`<module>`, `<feature>`, `<config-key>`, etc.) — no framework-specific vocabulary.

**Body content — over-prescribing tools and paths:**

- ❌ Before: "Grep `<frontend-dir>/` for references to `<symbol>`. Then grep `<backend-dir>/` for the matching handler."
- ✅ After: "Find all callers of `<symbol>` across the codebase."

**Body content — over-prescribing artifact format:**

- ❌ Before: "Write findings to `notes/<feature>-audit.md` with columns: module, owner, usage count, verdict. Format as a markdown table."
- ✅ After: "Produce a usage audit and record the decision with its rationale."

**Body content — walking through obvious steps:**

- ❌ Before: "Open `<config-file>`. Add the `<config-key>` block. Set `enabled: true`. Reference the credentials secret. Save."
- ✅ After: "Wire `<feature>` into the standard config (see `<canonical-module>` for the reference shape)."

**Body content — restating what the canonical reference already shows:**

- ❌ Before: "Implement the retry wrapper: wrap each call in a try/except, sleep with exponential backoff, cap at 5 retries, log each attempt, raise the original error on final failure."
- ✅ After: "Apply the project's standard retry pattern (see `<canonical-module>`)."

**Title — prescribing outcome before discovery:**

- ❌ Before: "Merge module X and module Y."
- ✅ After: "X/Y: assess overlap, consolidate if warranted."

**Title — naming means instead of goal:**

- ❌ Before: "Grep codebase for `<symbol>` references and document findings."
- ✅ After: "`<symbol>`: determine whether it's still in use."

**Title — committing to a fix before the cause is known:**

- ❌ Before: "Add caching layer to `<endpoint>`."
- ✅ After: "`<endpoint>`: investigate latency, mitigate if root cause warrants."

What stays in every ticket regardless of brevity: the *why* (1-2 sentences), the canonical pattern reference if any, the failure-prone wiring that links to sibling tickets, and the acceptance criteria. Everything else is negotiable based on how obvious the path is.

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

## Breaking a plan into tickets (vertical slices)

When converting a plan, PRD, Confluence doc, or epic into multiple implementation tickets, use **tracer-bullet vertical slices** — not horizontal layer slices.

### Vertical vs horizontal — the rule

- **Vertical slice (correct):** each ticket cuts through ALL integration layers end-to-end (schema + API + UI + tests). A completed slice is demoable on its own.
- **Horizontal slice (wrong):** ticket 1 = all schema, ticket 2 = all API, ticket 3 = all UI. Nothing works until the last ticket lands. Don't do this.

Prefer **many thin vertical slices** over few thick ones. Each slice must be independently demoable / verifiable.

### HITL vs AFK tagging

Tag each slice:
- **AFK** — agent can implement and merge without human interaction. Default to AFK where possible.
- **HITL** — needs human judgement (architectural decision, design review, manual testing, external access). Note WHY in the ticket.

### Pre-publish quiz

Before creating any tickets, present the proposed breakdown as a numbered list. For each slice, show:
- Title (short, descriptive)
- Type (HITL / AFK)
- Blocked by (other slices that must complete first)
- User stories covered (if source has them)

Ask the user:
- Does the granularity feel right? (too coarse / too fine)
- Are dependency relationships correct?
- Should any slices be merged or split further?
- Are HITL/AFK tags correct?

Iterate until the user approves. **Do not publish without approval.**

### Publish in dependency order

Create blockers first so you can reference real Jira keys in the `Blocked by` field of dependent tickets. See the two-pass pattern in **Multi-ticket workflows with dependencies** below.

### Slice ticket body template

```
## What to build

End-to-end behavior of this slice. Describe what the slice delivers, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Blocked by

PROJ-XXX (or "None — can start immediately")

## Parent

PROJ-YYY (parent epic / PRD ticket, if applicable)
```

Avoid file paths and code snippets — they go stale. Exception: small decision-encoding snippets (state machine, schema, type shape) inline if prose can't capture the decision precisely.

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
