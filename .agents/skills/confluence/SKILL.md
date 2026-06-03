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
- **Surface attachments inline.** Confluence Cloud's new UI no longer shows page attachments in the `•••` menu — uploaded files exist on the page (queryable via `GET /pages/{id}/attachments`) but readers can't see or click them unless they land directly on `/wiki/pages/viewpageattachments.action?pageId=<id>`. If a page has attachments that matter to the reader (run logs, screenshots, exports, etc.), add a "Run artefacts" / "Attachments" H2 section with a bulleted list of link-marked text nodes — one per attachment, `href` pointing at `<server>/wiki/download/attachments/<page-id>/<url-encoded-filename>`. See **Linking attachments inline** below for the exact pattern.

### `expand` node — exact ADF shape

```json
{
  "type": "expand",
  "attrs": {"title": "Click to expand"},
  "content": [ ...block nodes (paragraph, table, codeBlock, etc.)... ]
}
```

The `content` array holds normal block nodes — paragraphs, tables, code blocks, lists. The `title` is what the reader sees collapsed.

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

Stable, server-side — works without going through the page UI. Use this URL as the `href` when linking an attachment from inline ADF (see below).

### Linking attachments inline (new Confluence UI gotcha)

**The new Confluence Cloud UI removed the Attachments tab from the page `•••` menu.** Uploaded files still exist server-side and the API can list them, but readers will not see them unless one of these is true:

- They navigate to `<server>/wiki/pages/viewpageattachments.action?pageId=<id>` directly.
- Your page body contains links to the attachments.
- Your page body uses the Attachments macro (extension node — harder to construct from ADF than a plain bulleted list).

For programmatically-uploaded artefacts (run logs, exports, etc.), the simplest readable surface is a "Run artefacts" / "Attachments" H2 at the bottom of the page with a bulleted list of link-marked text nodes:

```json
{
  "type": "bulletList",
  "content": [
    {
      "type": "listItem",
      "content": [{
        "type": "paragraph",
        "content": [{
          "type": "text",
          "text": "<filename>",
          "marks": [{
            "type": "link",
            "attrs": {"href": "<server>/wiki/download/attachments/<page-id>/<url-encoded-filename>"}
          }]
        }]
      }]
    }
  ]
}
```

**Idempotent regeneration pattern.** When re-running an updater (e.g. after uploading more attachments), scan the ADF for the existing "Run artefacts" heading + its following `bulletList`, drop them, then append a fresh section built from the current `GET /pages/{id}/attachments` result. Don't blindly append on each run or the list duplicates.

```python
# Sketch — drop existing "Run artefacts" heading + the bulletList that follows it
new_content = []
skip_next_list = False
for node in doc["content"]:
    if (node.get("type") == "heading"
            and any(t.get("text", "").strip().lower() == "run artefacts"
                    for t in node.get("content", []))):
        skip_next_list = True
        continue
    if skip_next_list and node.get("type") == "bulletList":
        skip_next_list = False
        continue
    skip_next_list = False
    new_content.append(node)
doc["content"] = new_content
```

URL-encode the filename when building the `href` — spaces, parentheses, and unicode in attachment names break unencoded links.

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
