# Atlassian Document Format (ADF) Reference

Source: https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/

ADF is required for rich issue descriptions via Jira REST API v3. The `jira` CLI `-b` flag only supports plain text — use REST API when rich formatting is needed.

## Document wrapper

```json
{"type": "doc", "version": 1, "content": [ ...block nodes... ]}
```

## Block nodes

### Paragraph

```json
{"type": "paragraph", "content": [ ...inline nodes... ]}
```

### Bullet list

```json
{
  "type": "bulletList",
  "content": [
    {"type": "listItem", "content": [
      {"type": "paragraph", "content": [{"type": "text", "text": "item"}]}
    ]}
  ]
}
```

### Ordered list

Same structure as bulletList but `"type": "orderedList"`.

### Heading

```json
{"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Title"}]}
```

### Panel (callout)

```json
{
  "type": "panel",
  "attrs": {"panelType": "success"},
  "content": [ ...block nodes (paragraph, bulletList, orderedList, heading)... ]
}
```

Panel types: `info` (blue), `note` (purple), `warning` (yellow), `error` (red), `success` (green).

Allowed children: `paragraph`, `bulletList`, `orderedList`, `heading` (without marks).

### Code block

```json
{"type": "codeBlock", "attrs": {"language": "python"}, "content": [{"type": "text", "text": "code"}]}
```

### Rule (horizontal line)

```json
{"type": "rule"}
```

### Blockquote

```json
{"type": "blockquote", "content": [{"type": "paragraph", "content": [...]}]}
```

### Table

```json
{
  "type": "table",
  "content": [
    {"type": "tableRow", "content": [
      {"type": "tableHeader", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Header"}]}]},
      {"type": "tableHeader", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Header 2"}]}]}
    ]},
    {"type": "tableRow", "content": [
      {"type": "tableCell", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Cell"}]}]},
      {"type": "tableCell", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Cell 2"}]}]}
    ]}
  ]
}
```

### Media (images / attachments)

Display an attached image inline. Upload the attachment
to the issue first, then reference by attachment ID.

```json
{
  "type": "mediaSingle",
  "attrs": {
    "layout": "center",
    "width": 100,
    "widthType": "percentage"
  },
  "content": [
    {
      "type": "media",
      "attrs": {
        "id": "<attachment-uuid>",
        "type": "file",
        "collection": "jira-<issue-id>",
        "alt": "description",
        "width": 800,
        "height": 400
      }
    }
  ]
}
```

**mediaSingle attrs:**

| Attr | Values | Notes |
|------|--------|-------|
| layout | `center`, `wide`, `full-width`, `wrap-left`, `wrap-right`, `align-start`, `align-end` | Controls image placement |
| width | 1–100 | Percentage of content width |
| widthType | `percentage` | Only supported value |

**media attrs:**

| Attr | Type | Notes |
|------|------|-------|
| id | string | Attachment UUID from upload API response |
| type | `file` or `external` | `file` for attachments, `external` for URLs |
| collection | string | `jira-<issueId>` for Jira issues |
| alt | string | Alt text for accessibility |
| width | int | Pixel width (required for rendering) |
| height | int | Pixel height (required for rendering) |

For `type: "external"`, use `url` attr instead of
`id`/`collection`:

```json
{
  "type": "media",
  "attrs": {
    "type": "external",
    "url": "https://example.com/image.png",
    "alt": "description",
    "width": 800,
    "height": 400
  }
}
```

**Inline image** (within text flow, not block-level):

```json
{"type": "mediaInline", "attrs": {"id": "<attachment-uuid>", "type": "file", "collection": "jira-<issue-id>"}}
```

## Inline nodes

- `text` — `{"type": "text", "text": "hello", "marks": [...]}`
- `hardBreak` — `{"type": "hardBreak"}`
- `mention` — `{"type": "mention", "attrs": {"id": "account-id", "text": "@Name"}}`
- `emoji` — `{"type": "emoji", "attrs": {"shortName": ":thumbsup:"}}`
- `inlineCard` — `{"type": "inlineCard", "attrs": {"url": "https://..."}}`
- `status` — `{"type": "status", "attrs": {"text": "IN PROGRESS", "color": "blue"}}`

## Marks (text formatting)

Apply via `"marks"` array on text nodes:

| Mark | JSON |
|------|------|
| Bold | `{"type": "strong"}` |
| Italic | `{"type": "em"}` |
| Code | `{"type": "code"}` |
| Strike | `{"type": "strike"}` |
| Underline | `{"type": "underline"}` |
| Link | `{"type": "link", "attrs": {"href": "https://..."}}` |
| Color | `{"type": "textColor", "attrs": {"color": "#ff0000"}}` |
| Subscript | `{"type": "subsup", "attrs": {"type": "sub"}}` |
| Superscript | `{"type": "subsup", "attrs": {"type": "sup"}}` |

Combine marks: `"marks": [{"type": "strong"}, {"type": "code"}]`

## Common pattern: Acceptance Criteria

Green success panel with bold header + bullet list:

```json
{
  "type": "panel",
  "attrs": {"panelType": "success"},
  "content": [
    {"type": "paragraph", "content": [
      {"type": "text", "text": "Acceptance criteria:", "marks": [{"type": "strong"}]}
    ]},
    {
      "type": "bulletList",
      "content": [
        {"type": "listItem", "content": [{"type": "paragraph", "content": [
          {"type": "text", "text": "First criterion"}
        ]}]},
        {"type": "listItem", "content": [{"type": "paragraph", "content": [
          {"type": "text", "text": "Second criterion"}
        ]}]}
      ]
    }
  ]
}
```
