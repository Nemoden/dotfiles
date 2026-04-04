---
name: web-browser
description: "Allows to interact with web pages by performing actions such as clicking buttons, filling out forms, and navigating links. It works by remote controlling Google Chrome or Chromium browsers using the Chrome DevTools Protocol (CDP). When Claude needs to browse the web, it can use this skill to do so."
license: Stolen from Mario
---

# Web Browser Skill

Minimal CDP tools for collaborative site exploration.

## Start Chrome

```bash
./scripts/start.js              # Fresh profile
./scripts/start.js --profile    # Copy your profile (cookies, logins)
```

Start Chrome on `:9222` with remote debugging.

## Tab Management — ALWAYS USE TAB IDs

**Always capture the tab ID when opening a new tab and use `--tab-id` for all subsequent commands.**

```bash
# Open a tab and capture its ID
TAB=$(./scripts/nav.js https://example.com --new 2>&1 | grep "tab-id:" | awk '{print $2}')

# Use the ID for all subsequent commands on that tab
./scripts/screenshot.js --tab-id=$TAB
./scripts/eval.js --tab-id=$TAB 'document.title'

# Open multiple tabs in parallel — each gets its own ID
TAB1=$(./scripts/nav.js https://site-a.com --new 2>&1 | grep "tab-id:" | awk '{print $2}')
TAB2=$(./scripts/nav.js https://site-b.com --new 2>&1 | grep "tab-id:" | awk '{print $2}')
./scripts/screenshot.js --tab-id=$TAB1
./scripts/screenshot.js --tab-id=$TAB2
```

**Never use `--tab=<url-substring>`** — it is ambiguous when multiple tabs share the same domain and will silently operate on the wrong tab.

Only use `--tab=N` (numeric index) as a last resort when you don't have a tab ID.

## Navigate

```bash
./scripts/nav.js https://example.com                    # Navigate current (last) tab
./scripts/nav.js https://example.com --new              # Open in new tab, prints tab-id to stderr
./scripts/nav.js https://example.com --tab-id=<id>      # Navigate specific tab by targetId
./scripts/nav.js https://example.com --tab=0            # Navigate tab by index (avoid if possible)
```

Navigate a tab. Always prefer `--tab-id` for unambiguous tab targeting.

## Evaluate JavaScript

```bash
./scripts/eval.js 'document.title'
./scripts/eval.js --tab-id=<id> 'document.title'        # Evaluate in specific tab by targetId (preferred)
./scripts/eval.js --tab=0 'document.title'              # Evaluate in tab by index (avoid)
./scripts/eval.js 'JSON.stringify(Array.from(document.querySelectorAll("a")).map(a => ({ text: a.textContent.trim(), href: a.href })).filter(link => !link.href.startsWith("https://")))'
```

Execute JavaScript in a tab (async context). Be careful with string escaping, best to use single quotes.

## Batch — Navigate Multiple URLs and Extract Data

```bash
./scripts/batch.js '<expr>' url1 url2 url3 ...
./scripts/batch.js --wait=2000 '<expr>' url1 url2      # Wait 2s after each navigation
./scripts/batch.js --tab=bigw '<expr>' url1 url2       # Use a specific tab
./scripts/batch.js '<expr>' --urls-file=urls.txt       # Read URLs from file (one per line)
```

Navigates each URL in turn, evaluates `<expr>` after the page loads, and writes one JSON object per line to stdout:

```
{"url":"https://...","result":<expr result>}
{"url":"https://...","error":"<message>"}   # on failure
```

The expression has access to `url` (the current page URL as a string). Use `--wait` for JS-heavy pages that need render time. Use this instead of hand-rolling a loop in Node — it keeps one CDP connection open across all pages.

Example — extract the title from multiple pages:
```bash
./scripts/batch.js --wait=2000 'document.title' \
  https://example.com/page/1 \
  https://example.com/page/2
```

## Screenshot

```bash
./scripts/screenshot.js                    # Screenshot current (last) tab
./scripts/screenshot.js --tab-id=<id>      # Screenshot specific tab by targetId (preferred)
./scripts/screenshot.js --tab=0            # Screenshot tab by index (avoid)
```

Screenshot current viewport, returns temp file path

## Pick Elements

```bash
./scripts/pick.js "Click the submit button"
```

Interactive element picker. Click to select, Cmd/Ctrl+Click for multi-select, Enter to finish.

## Dismiss Cookie Dialogs

```bash
./scripts/dismiss-cookies.js          # Accept cookies
./scripts/dismiss-cookies.js --reject # Reject cookies (where possible)
```

Automatically dismisses EU cookie consent dialogs.

Run after navigating to a page:
```bash
./scripts/nav.js https://example.com && ./scripts/dismiss-cookies.js
```

## Background Logging (Console + Errors + Network)

Automatically started by `start.js` and writes JSONL logs to:

```
~/.cache/agent-web/logs/YYYY-MM-DD/<targetId>.jsonl
```

Manually start:
```bash
./scripts/watch.js
```

Tail latest log:
```bash
./scripts/logs-tail.js           # dump current log and exit
./scripts/logs-tail.js --follow  # keep following
```

Summarize network responses:
```bash
./scripts/net-summary.js
```
