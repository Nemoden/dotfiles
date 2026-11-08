---
name: web-browser
description: "Drive a separate agent Chrome over the Chrome DevTools Protocol: open named tabs, navigate, run JavaScript, take screenshots, batch-extract data from many URLs, capture the API calls of a page and replay them as curl. It can use the logins of one of the user's Chrome profiles, but it never touches the user's daily Chrome. Use when a task needs a real browser and the Claude in Chrome tools (mcp__claude-in-chrome__*) are not available, or for script-heavy or headless work."
license: Based on Mario Zechner's browser-tools
---

# Web Browser Skill

## Pick the right tool first

1. Public page, no JavaScript needed: use WebFetch or WebSearch.
2. The user wants their own, live browser: use the `mcp__claude-in-chrome__*` tools. If they are missing, tell the user to run `/chrome` (or start Claude Code with `--chrome`). Do not fall back to this skill on your own.
3. All other browser work: this skill.

## Rules

- NEVER start, quit, kill or `open -a` Google Chrome yourself. No `killall`, no `pkill`. `start.js` and `stop.js` are the only commands that start or stop a browser, and they reach only the agent browser.
- Name every tab you open (`--new=ebay`). Use that name later (`--tab=ebay`). Tab names belong to this Claude Code session. Other sessions cannot see them.
- Do not keep anything in shell variables. They do not survive to the next Bash call. The scripts keep the state for you.
- Every command prints `--- tabs of this session` to stderr. That list is the truth. Read it.
- When a command fails, it prints `next:`. Do that next.
- At the end of the task, run `tabs.js --close-all`. Leave the browser running. Other sessions can use it.

All scripts are in `~/.claude/skills/web-browser/scripts/`. The examples below use full paths.

## Profiles: whose logins

The agent browser runs from its own data folder in `~/.local/share/web-browser/<profile>/`. The user's daily Chrome folder is never written to.

```bash
~/.claude/skills/web-browser/scripts/start.js                    # profile AGENTS (default)
~/.claude/skills/web-browser/scripts/start.js --profile=Kirill   # logins of the user's "Kirill" profile
~/.claude/skills/web-browser/scripts/start.js --headless         # no window
```

- At each cold start, `start.js` copies the cookies and local storage of the daily Chrome profile with the same display name, folder name or email. Saved passwords are not copied.
- The user logs in to sites in their daily Chrome profile "AGENTS". The agent browser gets those logins at its next cold start. Logins made inside the agent window are replaced at the next cold start.
- With no matching daily profile, the agent profile starts empty, and the output lists the profiles that exist.
- If the browser for that profile already runs, `start.js` reuses it. It never restarts it.
- Use a profile other than AGENTS only when the user asks for it.

## Tabs and navigation

```bash
~/.claude/skills/web-browser/scripts/nav.js https://example.com --new=ex   # open a new tab named "ex"
~/.claude/skills/web-browser/scripts/nav.js https://example.com/b --tab=ex # navigate tab "ex"
~/.claude/skills/web-browser/scripts/nav.js https://example.com --new      # auto name: t1, t2, ...
~/.claude/skills/web-browser/scripts/tabs.js                                # list this session's tabs
~/.claude/skills/web-browser/scripts/tabs.js --close=ex                     # close tabs (comma list)
~/.claude/skills/web-browser/scripts/tabs.js --close-all                    # close all tabs of this session
```

`nav.js` waits for the page load event (up to 15 s, change it with `--timeout=<ms>`). It prints the final URL and title. If the page is still loading at the time limit, the tab is still usable.

When the session has exactly one tab, you can omit `--tab`.

## Run JavaScript

```bash
~/.claude/skills/web-browser/scripts/eval.js --tab=ex 'document.title'
~/.claude/skills/web-browser/scripts/eval.js --tab=ex 'const n = document.links.length; return n * 2'
~/.claude/skills/web-browser/scripts/eval.js --tab=ex - <<'JS'
return [...document.querySelectorAll("a")].map((a) => ({ text: a.textContent.trim(), href: a.href }));
JS
```

- The code can be an expression or a function body with `return`. It runs in an async function, so `await` works.
- With `-`, the code comes from stdin. Use this for long code, because it needs no shell quoting.
- Strings print as they are. All other values print as JSON on stdout.

## Batch: many URLs, one expression

```bash
~/.claude/skills/web-browser/scripts/batch.js --tab=ex '[document.title, url]' https://a.example https://b.example
~/.claude/skills/web-browser/scripts/batch.js --tab=ex --wait=2000 'document.title' --urls-file=/path/urls.txt
```

- Prints one JSON line per URL: `{"url":...,"result":...}` or `{"url":...,"error":...}`. The expression can use `url`.
- `--wait=<ms>` waits after each page load. Use it for pages that render late.
- The run stops before its time budget (`--budget=<s>`, default 100) and prints `rerun with --skip=N`. This keeps it inside the Bash time limit. Do not write your own nav plus eval loop.
- With no tabs in the session and no `--tab`, it opens a tab named `batch`.

## Screenshot, cookie banners, element picker

```bash
~/.claude/skills/web-browser/scripts/screenshot.js --tab=ex            # prints the PNG path
~/.claude/skills/web-browser/scripts/dismiss-cookies.js --tab=ex        # accept a cookie banner
~/.claude/skills/web-browser/scripts/dismiss-cookies.js --tab=ex --reject
~/.claude/skills/web-browser/scripts/pick.js --tab=ex "Click the submit button"   # the user clicks elements
```

## Stop the browser

```bash
~/.claude/skills/web-browser/scripts/stop.js                    # this session's profile
~/.claude/skills/web-browser/scripts/stop.js --profile=Kirill
```

`stop.js` refuses while other sessions still have tabs in that browser. Usually you do not need it: close your tabs and leave the browser running.

## Network: see the API calls of a page

For scraping, the API calls behind a page are usually better than its HTML. For the full recon method, use the `scraping-recon` skill. These commands give it the data.

```bash
~/.claude/skills/web-browser/scripts/start.js --watch                 # start the logger (also when the browser runs)
~/.claude/skills/web-browser/scripts/nav.js https://example.com --new=ex
~/.claude/skills/web-browser/scripts/net.js --tab=ex                  # list fetch, XHR and page requests, numbered
~/.claude/skills/web-browser/scripts/net.js --tab=ex --grep=/api/     # only URLs that contain /api/
~/.claude/skills/web-browser/scripts/net.js --tab=ex --all            # also scripts, styles, images
~/.claude/skills/web-browser/scripts/net.js --tab=ex --show=7         # request 7: headers, body, response headers, response body
~/.claude/skills/web-browser/scripts/net.js --tab=ex --curl=7         # request 7 as a curl command, with cookies
```

- The logger records only pages that load after it starts. If `net.js` shows nothing, run `start.js --watch` and load the page again.
- The logger saves JSON, XML, HTML and plain-text response bodies up to 2 MB. `--show` prints the path of the full body file. Use `jq` on that file.
- To test if a site needs a browser, run the `--curl` command, then remove headers and cookies one by one.
- The log holds the user's cookies and auth tokens. Never paste a `--curl` command or a log line into a ticket, doc or chat. Logs are in `~/.cache/web-browser/logs/<profile>/` (owner only). When the recon is done, tell the user where they are.
- `logs-tail.js [--follow]` prints the newest raw log of any tab, with console messages and page errors. `net-summary.js` counts its status codes.

## Example: full task

```bash
~/.claude/skills/web-browser/scripts/start.js
~/.claude/skills/web-browser/scripts/nav.js "https://www.ebay.com.au/sch/i.html?_nkw=outlander+antenna" --new=ebay
~/.claude/skills/web-browser/scripts/eval.js --tab=ebay - <<'JS'
return [...document.querySelectorAll("li.s-card")].slice(0, 10).map((li) => li.innerText.split("\n")[0]);
JS
~/.claude/skills/web-browser/scripts/tabs.js --close-all
```

## After you change a script

Run `~/.claude/skills/web-browser/scripts/selftest.js`. It checks every command above on a headless throwaway profile against a local test page. It also fails if the user's daily Chrome processes change.
