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
