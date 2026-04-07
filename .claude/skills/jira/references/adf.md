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
