# Notion shapes: rich_text, blocks, property values, DB filters

Source: developers.notion.com/reference (block, rich-text, property-value-object). Four hand-built shapes below.

## rich_text

Every text field is an **array** of rich_text objects.

```json
[
  {"type":"text","text":{"content":"plain "}},
  {"type":"text","text":{"content":"bold"},"annotations":{"bold":true}},
  {"type":"text","text":{"content":"link","link":{"url":"https://x.com"}}}
]
```

Annotations (default false/"default"): `bold`, `italic`, `strikethrough`, `underline`, `code`, `color` (e.g. `"red"`, `"blue_background"`). **Not markdown** — `**`, backticks, `\n` render literally; bold = annotation, line break = separate block. Max 2000 chars per `content`.

## Block nodes

`{"type":"<T>","<T>":{...}}` — inner key matches `type`. Append calls may omit `object`.

```json
{"type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"x"}}]}}
{"type":"heading_2","heading_2":{"rich_text":[...],"is_toggleable":false}}
{"type":"bulleted_list_item","bulleted_list_item":{"rich_text":[...],"children":[...]}}
{"type":"numbered_list_item","numbered_list_item":{"rich_text":[...]}}
{"type":"to_do","to_do":{"rich_text":[...],"checked":false}}
{"type":"code","code":{"rich_text":[...],"language":"python"}}
{"type":"callout","callout":{"rich_text":[...],"icon":{"type":"emoji","emoji":"💡"}}}
{"type":"toggle","toggle":{"rich_text":[...],"children":[...]}}
{"type":"quote","quote":{"rich_text":[...]}}
{"type":"divider","divider":{}}
{"type":"image","image":{"type":"external","external":{"url":"https://.../a.png"}}}
```

Headings: `heading_1..3`. Nest via `children`. Code `language` required (e.g. `python`, `bash`, `json`, `plain text`). Image: external url only via API. Toggle/toggleable-heading = where to hide bulk.

Table: `table` block with `table_row` children.
```json
{"type":"table","table":{"table_width":2,"has_column_header":true,"children":[
  {"type":"table_row","table_row":{"cells":[
    [{"type":"text","text":{"content":"H1"}}],[{"type":"text","text":{"content":"H2"}}]]}},
  {"type":"table_row","table_row":{"cells":[
    [{"type":"text","text":{"content":"a"}}],[{"type":"text","text":{"content":"b"}}]]}}
]}}
```
Each cell = array of rich_text; `table_width` = cells per row.

## Property values

In `POST /v1/pages` / `PATCH /v1/pages/{id}`. Key = property name, must match DB column exactly. Shape per column type:

```json
{
  "Name":    {"title":[{"text":{"content":"Title"}}]},
  "Notes":   {"rich_text":[{"text":{"content":"text"}}]},
  "Count":   {"number":42},
  "Status":  {"select":{"name":"In progress"}},
  "Tags":    {"multi_select":[{"name":"a"},{"name":"b"}]},
  "Done":    {"checkbox":true},
  "Due":     {"date":{"start":"2026-06-28","end":null}},
  "Site":    {"url":"https://x.com"},
  "Email":   {"email":"a@b.com"},
  "Phone":   {"phone_number":"+1..."},
  "Owner":   {"people":[{"id":"<user_id>"}]},
  "Related": {"relation":[{"id":"<page_id>"}]},
  "State":   {"status":{"name":"Done"}}
}
```

- `title` mandatory on every page (DB row: the `title`-typed column).
- `select`/`multi_select` auto-create missing options; `status` options must pre-exist.
- `date.start`: `YYYY-MM-DD` or full ISO 8601.
- Read-only, omit on write: `formula`, `rollup`, `created_time`, `last_edited_time`, `created_by`, `last_edited_by`.

## Database filters

`query` body `filter`. Inner key = property type. Single: `{"property":"Status","select":{"equals":"Done"}}`.

| Type | Operators |
|---|---|
| `title`/`rich_text` | `equals`, `contains`, `starts_with`, `ends_with`, `is_empty`, `is_not_empty` |
| `number` | `equals`, `greater_than`, `less_than`, `*_or_equal_to` |
| `checkbox` | `equals` (bool) |
| `select`/`status` | `equals`, `does_not_equal`, `is_empty` |
| `multi_select` | `contains`, `does_not_contain` |
| `date` | `equals`, `before`, `after`, `on_or_before`, `on_or_after`, `past_week`, `next_month`, … |
| `people`/`relation` | `contains` (id), `is_empty` |

Compound (`and`/`or`, nest ≤2 levels): `{"and":[<cond>,<cond>]}`.
Sorts: `[{"property":"Due","direction":"ascending"}]` or `[{"timestamp":"created_time","direction":"descending"}]`.

## Limits

Children nest only ~2 levels per create/append — deeper trees need follow-up appends.
