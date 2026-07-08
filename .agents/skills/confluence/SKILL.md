---
name: confluence
description: "Manage Confluence pages and spaces: list, search, create, read, update, and delete pages with rich ADF formatting. Use when the user asks to create/edit a wiki page, search Confluence, read page content, manage labels, add comments, or any Confluence-related task. Also triggers on: 'confluence', 'wiki page', 'create a page', 'update page', 'search wiki', 'confluence search', 'add to confluence'."
---

# Confluence

## Config

- Server: `$CC_CONFLUENCE_SERVER` env var (e.g. `https://myorg.atlassian.net`)
- Auth: basic auth — `$CC_CONFLUENCE_USER` + API token from `$CC_CONFLUENCE_TOKEN` env var
- API: Confluence REST API v2 (`/wiki/api/v2/...`) preferred, v1 (`/wiki/rest/api/...`) for search (CQL)

Read env vars once per session:
```bash
CONFLUENCE_SERVER="${CC_CONFLUENCE_SERVER:?Set CC_CONFLUENCE_SERVER env var}"
CONFLUENCE_USER="${CC_CONFLUENCE_USER:?Set CC_CONFLUENCE_USER env var}"
CONFLUENCE_TOKEN="${CC_CONFLUENCE_TOKEN:?Set CC_CONFLUENCE_TOKEN env var}"
```

## ADF reference

Confluence uses Atlassian Document Format for rich page content. Read [references/adf.md](references/adf.md) for the full node reference before constructing ADF JSON.

When reading pages, use `?body-format=atlas_doc_format` to get ADF. When writing, set `"representation": "atlas_doc_format"` in the body object.

## Page hygiene

A wiki page is a reference, not an essay. Default to terse unless the user asks otherwise.

- **Hide bulk in `expand` nodes.** Large tables, long code/config dumps, raw output — wrap in `{"type":"expand","attrs":{"title":"..."}}` so the page stays scannable. Reader sees a one-line caption + chevron; clicks to drill in.
- **Avoid table sprawl.** Large tables (many rows or wide columns) belong inside `expand`. If a table is both wide and tall, consider whether some rows belong in source files, not the wiki.
- **Headings are H2 (`level:2`)** for main sections; H3 only when nesting genuinely helps. The page title is already H1 implicitly — don't add another.
- **Code blocks**: use `codeBlock` with `attrs.language` set. Don't paste code in paragraphs.
- **Build ADF in a script, not hand-rolled JSON.** Long hand-typed ADF JSON breaks on a single typo. Use a small Python helper with `t()`, `p()`, `heading()`, `expand()`, `table()` functions and `json.dumps` at the end.
- **One page per topic.** If you find yourself adding a fourth unrelated H2, it's probably two pages.
- **Use interactive nodes when intent is actionable, not decorative.** If the value is meant to be checked/unchecked, picked, or otherwise manipulated in the UI, reach for the real ADF node — not plain text that looks similar:
  - **Checkbox / done state** → `taskList` + `taskItem` with `state: "TODO"` or `"DONE"`. NOT `"✅"` / `"☑"` / `"[x]"` text. The emoji is dead pixels; the taskItem is clickable, filterable, and surfaces in Confluence task views. See `references/adf.md` § Task list.
  - **Date** → inline `date` node with millisecond unix `timestamp`. NOT `"2026-06-02"` text. The date node renders as a pill, is sortable in tables, and respects the reader's locale. See `references/adf.md` § Inline nodes → `date`.
  - **Mention / user** → `mention` node with `attrs.id`. NOT `"@alice"` text.
  - **Status pill** → `status` node. NOT bold coloured text.
  - Rule of thumb: if the rendered cell needs to convey *state* (done, pending, dated, assigned, status), the underlying node is structured. Plain text is for prose.
- **Attachments aren't discoverable from the page itself.** Confluence Cloud's current UI doesn't surface page attachments in the page chrome (no "Attachments" entry in the overflow menu / `•••`). Uploaded files exist server-side and the REST API can list them, but a reader looking at the rendered page has no way to know they're there unless the page body references them. If attachments matter to the reader, decide how to surface them in the body — link, table cell, image (`mediaSingle`), expand block, prose, or skip surfacing entirely if they're audit-only. See `## Attachments` for API + URL shapes.

### `expand` node — exact ADF shape

```json
{
  "type": "expand",
  "attrs": {"title": "Click to expand"},
  "content": [ ...block nodes (paragraph, table, codeBlock, etc.)... ]
}
```

The `content` array holds normal block nodes — paragraphs, tables, code blocks, lists. The `title` is what the reader sees collapsed.

### Mermaid diagrams — rendered PNG + source in expand

Confluence doesn't render mermaid natively. Convention (see example page 6201999515): for each diagram emit BOTH, source first, image second:

1. `expand` (title like "Mermaid — <diagram name>") containing a `codeBlock` with `attrs.language: "mermaid"` and the raw mermaid source — keeps the diagram editable later.
2. `mediaSingle` with the rendered PNG right below the expand.

```json
{"type": "expand", "attrs": {"title": "Mermaid — sharing flow"},
 "content": [{"type": "codeBlock", "attrs": {"language": "mermaid"},
              "content": [{"type": "text", "text": "sequenceDiagram\n  ..."}]}]},
{"type": "mediaSingle",
 "attrs": {"layout": "full-width", "width": 1800, "widthType": "pixel"},
 "content": [{"type": "media",
              "attrs": {"type": "file", "id": "<fileId>",
                        "collection": "contentId-<page-id>",
                        "alt": "diagram.png",
                        "width": <px>, "height": <px>}}]}
```

Workflow (media node needs the page id + attachment fileId, so page must exist first):

1. Create page with placeholder body (or use existing page).
2. Upload the PNG as attachment (v1 API, see Attachments). The media `id` is `results[0].extensions.fileId` from the upload response (a UUID — NOT the `attXXXX` attachment id).
3. PUT the full body with `media.attrs.id = fileId`, `collection = "contentId-<page-id>"`, `width`/`height` = actual pixel dims.

PNG rendering notes:

- User typically exports from mermaid.live — ask for the export or render via `mmdc` if available. Prefer **transparent background** exports (check: first pixel alpha == 0); opaque white duplicates look wrong in dark mode.
- `mediaSingle` layout: `full-width` + width ~1800 for big sequence diagrams, `wide` + width ~1100 for timelines/smaller. `width`/`height` on the `media` node itself are the intrinsic pixel dims of the PNG.
- Mermaid source gotchas for clean renders: no `;` inside sequenceDiagram message text (parse error), avoid unicode emphasis markers if the user's terminal renderer chokes — plain words like CRITICAL/FIXED survive everywhere.

---

## Spaces

### List spaces

```bash
curl -s -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  "$CONFLUENCE_SERVER/wiki/api/v2/spaces?limit=25"
```

Filter by type: `?type=global` or `?type=personal`.
Filter by keys: `?keys=SPACE1&keys=SPACE2`.
Sort: `?sort=name` (or `-name`, `key`, `-key`).

### Get space by ID

```bash
curl -s -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  "$CONFLUENCE_SERVER/wiki/api/v2/spaces/<space-id>"
```

---

## Pages

### List pages in a space

```bash
curl -s -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  "$CONFLUENCE_SERVER/wiki/api/v2/spaces/<space-id>/pages?limit=25&sort=-modified-date&body-format=atlas_doc_format"
```

Omit `body-format` to skip page bodies (faster for listing titles only).

### Get page by ID

```bash
curl -s -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  "$CONFLUENCE_SERVER/wiki/api/v2/pages/<page-id>?body-format=atlas_doc_format"
```

Response includes: `id`, `title`, `spaceId`, `parentId`, `version.number`, `body.atlas_doc_format.value` (ADF JSON string).

### Get child pages

```bash
curl -s -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  "$CONFLUENCE_SERVER/wiki/api/v2/pages/<page-id>/children?limit=25"
```

### Create page

```bash
curl -s -X POST "$CONFLUENCE_SERVER/wiki/api/v2/pages" \
  -H "Content-Type: application/json" \
  -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  -d '{
    "spaceId": "<space-id>",
    "title": "Page title",
    "parentId": "<parent-page-id>",
    "status": "current",
    "body": {
      "representation": "atlas_doc_format",
      "value": "{\"type\":\"doc\",\"version\":1,\"content\":[...]}"
    }
  }'
```

Notes:
- `parentId` is optional. Omit to create at space root.
- `status`: `current` (published) or `draft`.
- The `value` field is a **JSON string** (escaped ADF), not a nested object.

### Update page

```bash
curl -s -X PUT "$CONFLUENCE_SERVER/wiki/api/v2/pages/<page-id>" \
  -H "Content-Type: application/json" \
  -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  -d '{
    "id": "<page-id>",
    "status": "current",
    "title": "Updated title",
    "version": {
      "number": <current_version + 1>,
      "message": "Updated via API"
    },
    "body": {
      "representation": "atlas_doc_format",
      "value": "{\"type\":\"doc\",\"version\":1,\"content\":[...]}"
    }
  }'
```

**You must increment the version number.** Fetch the page first to get the current version, then set `number` to current + 1.

### Editing safely

Always GET page right before PUT. Two reasons:
- need current `version.number` (PUT rejects stale)
- user may edit page in browser concurrently. Stale local copy → overwrite their edits.

ADF is JSON tree. Edit in-place, don't rebuild whole doc from source. Find target node by heading, replace one subtree, keep rest verbatim.

Pattern: GET → mutate one node → PUT (`version+1`). Never rebuild full ADF unless user explicitly says "rewrite page".

### Delete page

```bash
curl -s -X DELETE "$CONFLUENCE_SERVER/wiki/api/v2/pages/<page-id>" \
  -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN"
```

---

## Search (CQL)

Search uses v1 API with Confluence Query Language (CQL).

```bash
curl -s -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  "$CONFLUENCE_SERVER/wiki/rest/api/content/search?cql=<url-encoded-cql>&limit=10&expand=body.atlas_doc_format"
```

### CQL examples

| Goal | CQL |
|------|-----|
| Pages in a space | `space = "MYSPACE" AND type = page` |
| Search by title | `title = "My Page"` or `title ~ "partial*"` |
| Full-text search | `text ~ "search term"` |
| Recently modified | `lastModified > now("-7d")` |
| By label | `label = "my-label"` |
| Combined | `space = "DEV" AND label = "api" AND text ~ "authentication"` |

URL-encode the CQL value. The `~` operator is "contains" (supports wildcards). The `=` operator is exact match.

Add `&expand=body.atlas_doc_format` to include ADF body in search results.

---

## Comments

### List page comments

```bash
curl -s -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  "$CONFLUENCE_SERVER/wiki/api/v2/pages/<page-id>/footer-comments?body-format=atlas_doc_format"
```

### Add comment

```bash
curl -s -X POST "$CONFLUENCE_SERVER/wiki/api/v2/pages/<page-id>/footer-comments" \
  -H "Content-Type: application/json" \
  -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  -d '{
    "body": {
      "representation": "atlas_doc_format",
      "value": "{\"type\":\"doc\",\"version\":1,\"content\":[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"My comment\"}]}]}"
    }
  }'
```

---

## Attachments

### List page attachments

```bash
curl -s -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  "$CONFLUENCE_SERVER/wiki/api/v2/pages/<page-id>/attachments?limit=50"
```

Returns `results[]` with `id` (`attXXXXX`), `title` (filename), `createdAt`, `mediaType`, `fileSize`, `webuiLink`, `downloadLink`.

### Upload an attachment

Use v1 API. Requires multipart form + the `X-Atlassian-Token: nocheck` header (XSRF bypass for API uploads).

```bash
curl -s -X POST "$CONFLUENCE_SERVER/wiki/rest/api/content/<page-id>/child/attachment" \
  -H "X-Atlassian-Token: nocheck" \
  -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  -F "file=@/path/to/file.txt" \
  -F "comment=Optional comment describing this file"
```

Response: `results[0].id`, `.title`.

### Direct download URL

`<server>/wiki/download/attachments/<page-id>/<url-encoded-filename>`

Stable, server-side. Use as `href` when referencing an attachment from page body ADF. URL-encode the filename — spaces, parentheses, unicode break unencoded links.

### Surfacing attachments in the page body

Attachments uploaded via the API exist server-side but are not auto-rendered anywhere on the page (see Page hygiene → "Attachments aren't discoverable"). If readers should see them, put something in the body that points at them. The right shape depends on the page:

- **Single file referenced from prose** → inline `link`-marked text.
- **Image / screenshot** → `mediaSingle` + `media` node (see ADF reference).
- **Several files of equal weight** → list, table column, or `expand` block — pick what fits the surrounding content.
- **Audit-only logs nobody needs to click** → no body reference needed; the API listing is the audit trail.

Whichever surface you pick, use the direct download URL above as the `href`.

### Re-running an updater that surfaces attachments

If your code regenerates the body section that links attachments (e.g. after each new upload), make the regeneration idempotent: locate the section by a stable marker you control (heading text, anchor, an HTML comment node), drop the prior version, then re-emit. Appending without dropping duplicates the section every run.

### Delete an attachment

```bash
curl -s -X DELETE "$CONFLUENCE_SERVER/wiki/api/v2/attachments/<attachment-id>" \
  -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN"
```

---

## Labels

### Get labels on a page

```bash
curl -s -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  "$CONFLUENCE_SERVER/wiki/api/v2/pages/<page-id>/labels"
```

### Add labels

```bash
curl -s -X POST "$CONFLUENCE_SERVER/wiki/rest/api/content/<page-id>/label" \
  -H "Content-Type: application/json" \
  -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  -d '[{"prefix": "global", "name": "my-label"}]'
```

### Remove label

```bash
curl -s -X DELETE "$CONFLUENCE_SERVER/wiki/rest/api/content/<page-id>/label/<label-name>" \
  -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN"
```

---

## Current user

```bash
curl -s -u "$CONFLUENCE_USER:$CONFLUENCE_TOKEN" \
  "$CONFLUENCE_SERVER/wiki/rest/api/user/current"
```

Returns `accountId`, `displayName`, `email`. Useful for finding your personal space.

## Tips

- **Page IDs** are numeric strings (e.g. `5546771462`). You'll see them in URLs and API responses.
- **Space IDs** are also numeric. Use `GET /wiki/api/v2/spaces?keys=MYKEY` to resolve a space key to an ID.
- **ADF value is a JSON string** — when creating/updating pages, the `value` field must be a stringified JSON document, not a nested object.
- **Version conflicts** — always fetch current version before updating. The API rejects stale version numbers.
- **Large pages** — the ADF body can be very large. Omit `body-format` when listing pages if you only need titles/metadata.
