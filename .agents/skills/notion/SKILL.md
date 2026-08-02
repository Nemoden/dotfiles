---
name: notion
description: "Manage Notion: search, read pages, query databases, create/update pages, edit page content (markdown or blocks), manage database schema, and handle comments. Use when the user asks to find/read a Notion page, search Notion, create or edit a Notion page, append content, query a Notion database, filter/sort database rows, add a database row, change a database schema, or read/add comments. Also triggers on: 'notion', 'notion page', 'notion database', 'notion doc', 'add to notion', 'update notion', 'search notion'."
---

# Notion

## Auth

Token: `$AGENTS_NOTION_TOKEN` (vendor-neutral name; any agent can use it). A **PAT** (personal access token, full workspace perms) needs no per-page sharing — prefer it. An internal-integration token sees only pages explicitly shared with it (page `•••` → Connections → add); empty `search`/`object_not_found` = missing share, not bad id.

Base URL `https://api.notion.com`. Every request needs three headers (assumed in all examples below):

```bash
TOK="${AGENTS_NOTION_TOKEN:?Set AGENTS_NOTION_TOKEN}"
H=(-H "Authorization: Bearer $TOK" -H "Notion-Version: 2026-03-11" -H "Content-Type: application/json")
```

**Version matters.** `2026-03-11` is pinned throughout. Older versions differ in ways that silently change behaviour — see [Version gotchas](#version-gotchas) before copying any snippet from elsewhere.

## Workspace instructions — check `_AGENTS` first

At the start of any Notion task, look for a top-level page titled **`_AGENTS`** (`query:"_AGENTS"`, confirm `parent.type == "workspace"`). It's the workspace's agent guide — like `CLAUDE.md`/`AGENTS.md` but living in Notion. If it exists, read its blocks before acting; it carries workspace-specific structure, conventions, and placement rules. **If absent, skip silently** — not every workspace has one. Keep this skill universal: never hardcode one workspace's layout here; that knowledge belongs in `_AGENTS`.

## Core model

Three things, three APIs:

- **Markdown** = the whole page body as one string. `GET`/`PATCH /v1/pages/{id}/markdown`. **Default for read, summarize, and edit** — far cheaper than block trees and needs no JSON assembly.
- **Properties** = structured fields on the page object (title, dates, selects, relations; for a DB row, the column values). `GET`/`PATCH /v1/pages/{id}`.
- **Blocks** = the body as a typed tree. `GET`/`PATCH /v1/blocks/{id}/children`. Use only when you need block ids, exact structure, or a block type markdown can't express.

Block, `rich_text`, property-value, and DB-filter shapes: [references/blocks.md](references/blocks.md). Read it before building any block JSON or property value.

## Endpoints

| Action | Call |
|---|---|
| Search (title only) | `POST /v1/search` |
| **Read page body as markdown** | `GET /v1/pages/{id}/markdown` |
| **Edit page body as markdown** | `PATCH /v1/pages/{id}/markdown` |
| Get page properties | `GET /v1/pages/{id}` |
| Create page (from markdown or blocks) | `POST /v1/pages` |
| Read page body as blocks | `GET /v1/blocks/{id}/children?page_size=100` |
| Append blocks | `PATCH /v1/blocks/{id}/children` |
| Edit / trash block | `PATCH` / `DELETE /v1/blocks/{id}` |
| Get DB + its data source ids | `GET /v1/databases/{id}` |
| Get data source schema | `GET /v1/data_sources/{data_source_id}` |
| Query rows (filter/sort) | `POST /v1/data_sources/{data_source_id}/query` |
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

**Default — markdown.** One call, whole body, no recursion:

```bash
curl -s "https://api.notion.com/v1/pages/<id>/markdown" "${H[@]}"
```

Returns `{"object":"page_markdown","id":…,"markdown":"…","truncated":false,"unknown_block_ids":[]}`.

- `truncated: true` → page exceeded ~20 000 blocks; content is incomplete.
- `unknown_block_ids` non-empty → those blocks came back as `<unknown>` (permissions or depth). Re-request each id **as the `page_id`** of this same endpoint to fetch it.
- `?include_transcript=true` to expand meeting-note transcripts (default `false`, shows a placeholder URL).

Properties are separate from body — markdown does not include them:

```bash
curl -s "https://api.notion.com/v1/pages/<id>" "${H[@]}"            # properties
curl -s "https://api.notion.com/v1/blocks/<id>/children?page_size=100" "${H[@]}"  # blocks, if you need ids
```

Blocks recurse: each child with `has_children: true` needs its own call. That is the reason to prefer markdown.

## Create a page

Needs a `parent`. Body via **`markdown`** (preferred) or `children` — mutually exclusive, never both.

```bash
curl -s -X POST "https://api.notion.com/v1/pages" "${H[@]}" -d '{
  "parent": {"page_id": "<id>"},
  "markdown": "# Title\n\nBody text.\n\n## Section\n- [ ] task"
}'
```

Omit `properties.title` and the first `#` heading becomes the page title. In JSON use `\n` for a new block; `<br>` for a line break *inside* one paragraph.

Into a database — `properties` keys must match the data source schema exactly (fetch it first), parent stays `database_id`:

```bash
curl -s -X POST "https://api.notion.com/v1/pages" "${H[@]}" -d '{
  "parent": {"database_id": "<id>"},
  "properties": {"Name": {"title":[{"text":{"content":"Row"}}]},
                 "Status": {"select":{"name":"Todo"}}},
  "markdown": "Body of the row page."
}'
```

## Edit page body (markdown)

`PATCH /v1/pages/{id}/markdown` with a command object. Two commands worth using; two legacy ones to recognise but avoid.

**`update_content` — targeted search/replace. The default for edits.**

```bash
curl -s -X PATCH "https://api.notion.com/v1/pages/<id>/markdown" "${H[@]}" -d '{
  "type": "update_content",
  "update_content": {
    "content_updates": [
      {"old_str": "Draft proposal", "new_str": "Draft proposal (due Friday)"}
    ]
  }
}'
```

Each `old_str` must match **exactly one** location or the call fails — same discipline as a code Edit tool. Add `"replace_all_matches": true` to hit every occurrence deliberately. Read the page first so `old_str` is copied, not remembered.

**`replace_content` — swap the entire body.**

```bash
curl -s -X PATCH "https://api.notion.com/v1/pages/<id>/markdown" "${H[@]}" \
  -d '{"type":"replace_content","replace_content":{"new_str":"# Fresh\n\nAll new."}}'
```

Destructive: everything not in `new_str` is gone. Prefer `update_content` unless genuinely rewriting.

Legacy (`insert_content`, `replace_content_range`) use an ellipsis selector `"start text...end text"`. Recognise them in old code; write the two above instead.

## Append blocks

Only when you need typed blocks rather than markdown.

```bash
curl -s -X PATCH "https://api.notion.com/v1/blocks/<id>/children" "${H[@]}" -d '{
  "children": [ <blocks> ],
  "position": {"type": "after_block", "after_block": {"id": "<block_id>"}}
}'
```

`position` is `{"type":"end"}` (default), `{"type":"start"}`, or `{"type":"after_block","after_block":{"id":…}}`. The old flat `after: "<id>"` string is gone; sending both is an error.

Edit a block = `PATCH /v1/blocks/{id}` with the block's full type body. `DELETE` moves to trash (recoverable ~30 days), doesn't erase.

## Query a database

Two ids. A database is a container; the rows live in a **data source**. Query needs the data source id.

```bash
# 1. database -> data source ids
curl -s "https://api.notion.com/v1/databases/<database_id>" "${H[@]}" | jq '.data_sources'
# [{"id":"<data_source_id>","name":"…"}]

# 2. query the data source
curl -s -X POST "https://api.notion.com/v1/data_sources/<data_source_id>/query" "${H[@]}" -d '{
  "filter": {"property": "Status", "select": {"equals": "Done"}},
  "sorts": [{"property": "Due", "direction": "ascending"}]
}'
```

Most databases have exactly one data source; take `data_sources[0]` unless the user means otherwise.

Shortcut when searching by name — filter straight to data sources and skip the database lookup:

```bash
curl -s -X POST "https://api.notion.com/v1/search" "${H[@]}" \
  -d '{"query":"Tasks","filter":{"property":"object","value":"data_source"}}'
```

Each result is a `data_source` whose `.id` is queryable directly, with `parent.database_id` pointing back at its container.

Add a row = create a page with `parent.database_id` (not data_source_id). Type-specific filter/value shapes: blocks.md.

## Enhanced markdown

The `/markdown` endpoints speak Notion-flavored Markdown: CommonMark plus XML-ish tags for Notion-only blocks. **Indent children with tabs**, one tab per level.

```
<callout icon="🎯" color="blue_bg">
	Ship by **Friday**.
</callout>

<details color="gray">
<summary>Toggle title</summary>
	Hidden child content
</details>

<columns>
	<column>Left</column>
	<column>Right</column>
</columns>

<table_of_contents color="gray"/>
```

Inline: `<span underline="true">x</span>`, `<span color="blue">x</span>`, `$x^2$` (block math `$$…$$`), mentions `<mention-page url="…">Title</mention-page>`, `<mention-user url="…"/>`, `<mention-date start="2026-05-15"/>`.

Colors: `gray brown orange yellow green blue purple pink red`, plus `*_bg` background variants.

## Comments

```bash
curl -s "https://api.notion.com/v1/comments?block_id=<id>" "${H[@]}"
curl -s -X POST "https://api.notion.com/v1/comments" "${H[@]}" \
  -d '{"parent":{"page_id":"<id>"},"rich_text":[{"text":{"content":"text"}}]}'
```

Reply to a thread uses `discussion_id` instead of `parent`.

## Version gotchas

Pinned to `2026-03-11`. Snippets written for older versions break subtly, not loudly:

| Since | Old | Now |
|---|---|---|
| 2025-09-03 | `POST /v1/databases/{id}/query` | `POST /v1/data_sources/{id}/query` |
| 2026-03-11 | `after: "<block_id>"` | `position: {"type":"after_block",…}` |
| 2026-03-11 | `archived: true` | `in_trash: true` (req + resp) |
| 2026-03-11 | `transcription` block | `meeting_notes` block |

`/markdown` endpoints require `2026-03-11` — they do not exist on `2025-09-03` or earlier. A stale `Notion-Version` header is the first thing to check on an unexpected 400/404.

## Gotchas

- **Pagination everywhere.** Search/query/blocks return `has_more` + `next_cursor`; loop with `start_cursor`. Max 100/page. The markdown endpoint does not paginate — it sets `truncated` instead.
- **Rate limit ~3 req/s** average. Bursts get `429` with `Retry-After`; back off, don't spin.
- **Prefer markdown over block JSON.** Fewer calls, no recursion, no brace errors. Reach for blocks only when you need block ids or a type markdown can't express.
- **Build any block/property JSON in a Python helper + `json.dumps`**, not by hand — one brace breaks the request. **POST from inside that same Python process** (`urllib`/`requests`), not via a temp file piped to curl. Writing the payload to a file while also redirecting the script's stdout to that file (`python … > /tmp/p.json`) truncates/clobbers it — you POST an empty body and get `invalid_json`.
- **`old_str` must be copied from a fresh read**, never recalled. A near-miss either fails or silently matches the wrong spot.
- **Property names/types must match the schema exactly.** Rejected write → re-fetch schema.
- **Deletes are recoverable, overwrites are not.** `DELETE` trashes (~30 days); `replace_content` and a bad `old_str` overwrite in place, and page history is 7 days on Free plans. Read before you write.
- Writing a page/doc: terse, headings, code in fenced blocks, bulk inside `<details>` toggles.
- No OpenAPI spec. On unexpected failure check https://developers.notion.com/reference/intro, then update this skill if a shape is wrong.
