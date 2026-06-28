---
name: notion
description: "Manage Notion: search, read pages, query databases, create/update pages, edit page content (blocks), manage database schema, and handle comments. Use when the user asks to find/read a Notion page, search Notion, create or edit a Notion page, append content, query a Notion database, filter/sort database rows, add a database row, change a database schema, or read/add comments. Also triggers on: 'notion', 'notion page', 'notion database', 'notion doc', 'add to notion', 'update notion', 'search notion'."
---

# Notion

## Auth

Token: `$AGENTS_NOTION_TOKEN` (vendor-neutral name; any agent can use it). A **PAT** (personal access token, full workspace perms) needs no per-page sharing — prefer it. An internal-integration token sees only pages explicitly shared with it (page `•••` → Connections → add); empty `search`/`object_not_found` = missing share, not bad id.

Base URL `https://api.notion.com`. Every request needs three headers (assumed in all examples below):

```bash
TOK="${AGENTS_NOTION_TOKEN:?Set AGENTS_NOTION_TOKEN}"
H=(-H "Authorization: Bearer $TOK" -H "Notion-Version: 2022-06-28" -H "Content-Type: application/json")
```

## Workspace instructions — check `_AGENTS` first

At the start of any Notion task, look for a top-level page titled **`_AGENTS`** (`query:"_AGENTS"`, confirm `parent.type == "workspace"`). It's the workspace's agent guide — like `CLAUDE.md`/`AGENTS.md` but living in Notion. If it exists, read its blocks before acting; it carries workspace-specific structure, conventions, and placement rules. **If absent, skip silently** — not every workspace has one. Keep this skill universal: never hardcode one workspace's layout here; that knowledge belongs in `_AGENTS`.

## Core model: properties vs blocks

- **Properties** = structured fields on the page object (title, dates, selects, relations; for a DB row, the column values). `GET`/`PATCH /v1/pages/{id}`.
- **Blocks** = body content (paragraphs, headings, lists, code…) in a separate tree. `GET`/`PATCH /v1/blocks/{id}/children`. Reading/writing body text = blocks API, not pages.

Block, `rich_text`, property-value, and DB-filter shapes: [references/blocks.md](references/blocks.md). Read it before building any block JSON or property value.

## Endpoints

| Action | Call |
|---|---|
| Search (title only) | `POST /v1/search` |
| Get page properties | `GET /v1/pages/{id}` |
| Create page | `POST /v1/pages` |
| Read page body | `GET /v1/blocks/{id}/children?page_size=100` |
| Append body | `PATCH /v1/blocks/{id}/children` |
| Edit / archive block | `PATCH` / `DELETE /v1/blocks/{id}` |
| Get DB schema | `GET /v1/databases/{id}` |
| Query DB (filter/sort) | `POST /v1/databases/{id}/query` |
| Create / alter DB | `POST /v1/databases` / `PATCH /v1/databases/{id}` |
| List / add comment | `GET /v1/comments?block_id={id}` / `POST /v1/comments` |

Ids: the 32-char hex at the end of a Notion URL (dashed or undashed both work). Discover via search, don't ask the user to paste UUIDs.

## Search

Matches **titles only** (not body), pages + databases. **Pass a `query`** — empty body lists the whole workspace (paginated 100/page) and is rarely what you want. Add `"filter":{"property":"object","value":"page"}` to exclude databases.

```bash
curl -s -X POST "https://api.notion.com/v1/search" "${H[@]}" \
  -d '{"query":"address history","page_size":20}'
```

## Read a page

```bash
curl -s "https://api.notion.com/v1/pages/<id>" "${H[@]}"                       # properties
curl -s "https://api.notion.com/v1/blocks/<id>/children?page_size=100" "${H[@]}" # body
```

Nested blocks need a recursive call on each child with `has_children: true`.

## Create a page

Needs a `parent`: page → `properties` holds only `title`, body in `children`; database → `properties` keys must match the DB schema exactly (fetch it first).

```bash
curl -s -X POST "https://api.notion.com/v1/pages" "${H[@]}" -d '{
  "parent": {"page_id": "<id>"},
  "properties": {"title": [{"text": {"content": "Title"}}]},
  "children": [ <blocks — see references/blocks.md> ]
}'
```

## Append / edit body

```bash
curl -s -X PATCH "https://api.notion.com/v1/blocks/<id>/children" "${H[@]}" \
  -d '{"children": [ <blocks> ]}'
```

Append-only; position with `after: <block_id>`. Edit = `PATCH /v1/blocks/{id}` with the block's full type body. `DELETE` archives (hides), doesn't erase.

## Query a database

```bash
curl -s -X POST "https://api.notion.com/v1/databases/<id>/query" "${H[@]}" -d '{
  "filter": {"property": "Status", "select": {"equals": "Done"}},
  "sorts": [{"property": "Due", "direction": "ascending"}]
}'
```

Add a row = create a page with `parent.database_id`. Type-specific filter/value shapes: blocks.md.

## Comments

```bash
curl -s "https://api.notion.com/v1/comments?block_id=<id>" "${H[@]}"
curl -s -X POST "https://api.notion.com/v1/comments" "${H[@]}" \
  -d '{"parent":{"page_id":"<id>"},"rich_text":[{"text":{"content":"text"}}]}'
```

Reply to a thread uses `discussion_id` instead of `parent`.

## Gotchas

- **Pagination everywhere.** Search/query/blocks return `has_more` + `next_cursor`; loop with `start_cursor`. Max 100/page.
- **Build block/property JSON in a Python helper + `json.dumps`**, not by hand — one brace breaks the request. **POST from inside that same Python process** (`urllib`/`requests`), not via a temp file piped to curl. Writing the payload to a file while also redirecting the script's stdout to that file (`python … > /tmp/p.json`) truncates/clobbers it — you POST an empty body and get `invalid_json`.
- **Property names/types must match the DB schema exactly.** Rejected write → re-fetch schema.
- Writing a page/doc: terse, headings, code in `code` blocks, bulk inside toggles.
- No OpenAPI spec. On unexpected failure check https://developers.notion.com/reference/intro, then update this skill if a shape is wrong.
