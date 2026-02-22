---
name: scraping-recon
description: "Investigate websites to determine the best scraping strategy. Use when the user wants to scrape a site and needs to figure out the approach — API discovery, site structure analysis, anti-bot detection, pagination patterns, authentication, data source mapping. Produces a scraping strategy report. Also use when user says 'recon', 'how to scrape', 'figure out how to scrape', 'scraping approach', 'investigate site', or asks about a site's structure for scraping purposes."
---

# Scraping Reconnaissance

Systematic investigation of a target site to determine the optimal scraping strategy. This skill provides the *workflow and domain knowledge*, not the browser mechanics.

**Browser automation:** If a browser skill is available (web-browser, chrome-devtools, or similar), use it for Phases 2-3. If not, use curl to fetch page source and the user's own browser + DevTools for network analysis. The workflow is the same — the browser skill just makes it scriptable.

**Legal note:** Check the site's Terms of Service and applicable law before scraping. Note any restrictions in the recon report. This is a practical consideration — ToS violations can get IPs banned or accounts terminated, which affects the scraping strategy itself.

## Investigation Phases

Execute in order. Each phase informs the next. Skip phases when findings make them irrelevant (e.g., if Phase 1 reveals a public API with docs, skip straight to the probe).

### Phase 1: Passive Discovery

No browser needed. Start with what's publicly declared.

```bash
curl -s https://TARGET/robots.txt
```

**What to extract from robots.txt:**
- `Sitemap:` directives — often the only reliable way to find sitemap URLs
- `Disallow:` paths — these reveal internal structure: API endpoints, search URLs, admin panels, staging paths. Disallowed paths are a map of what exists, not a list of what to avoid.
- User-agent-specific rules — if they have rules for specific bots (Googlebot, AhrefsBot), it hints at their detection awareness level

```bash
curl -s https://TARGET/sitemap.xml
curl -s https://TARGET/sitemap_index.xml
```

**What to extract from sitemaps:**
- URL patterns and hierarchy (how are categories/products organized?)
- `<lastmod>` timestamps (how fresh is the data?)
- `<changefreq>` and `<priority>` (what do they consider important?)
- Nested sitemap references (sitemap index → child sitemaps)
- Total URL count (scale of the scraping task)

Also check common sitemap locations if not in robots.txt:
- `/sitemap.xml`, `/sitemap_index.xml`, `/sitemaps/sitemap.xml`
- `/sitemap-products.xml`, `/sitemap-categories.xml`

### Phase 2: Page Structure Analysis

Fetch a representative page (product page, listing page, whatever the target data lives on). Use browser skill or `curl -s https://TARGET/page`.

**Check the page source (not rendered DOM) first:**

1. **Inline data blobs** — many modern sites embed all their data in the HTML:
   - `__NEXT_DATA__` (Next.js) — full page props as JSON in a `<script>` tag
   - `__NUXT__` / `__NUXT_DATA__` (Nuxt.js)
   - `window.__INITIAL_STATE__`, `window.__data`, `window.__PRELOADED_STATE__`
   - JSON-LD (`<script type="application/ld+json">`) — structured product/org data
   - Microdata / RDFa attributes in HTML elements

   If these exist, you may not need to parse HTML at all — just extract the JSON blob.

2. **Meta tags** — `og:` tags, `twitter:` cards, canonical URLs reveal data structure
3. **Link tags** — API endpoints, alternate versions, pagination hints (`rel="next"`)

**Then check rendered DOM (requires browser or JS execution):**

4. **CSS selectors for target data** — product titles, prices, availability, pagination
5. **Rendered vs source comparison** — if data is only in rendered DOM (not in source), the site requires JavaScript execution. This is the key decision: can you use plain HTTP or do you need a browser?
6. **Price formats** — original price, sale price, member price, currency symbols, multiple representations of the same price
7. **Availability indicators** — how is stock status shown? CSS class? Data attribute? Missing element? Badge text?

### Phase 3: Network Traffic Analysis

Browse the site and capture network traffic. With a browser skill, use its network logger. Without one, use the browser's DevTools Network tab manually and export HAR or copy requests as curl.

Navigate as a user would — browse categories, paginate, click into detail pages, use search/filters.

**What to capture:**
- XHR/fetch requests to internal APIs (these are your scraping goldmine)
- Request patterns: REST endpoints, GraphQL queries, search APIs
- Query parameters: pagination (`page`, `offset`, `cursor`), filters, sorting
- Response shapes: JSON structure, field names, nested objects
- Authentication headers: Bearer tokens, API keys, session cookies
- Content-Type headers on responses

**Key patterns to look for:**
- `/api/`, `/v1/`, `/graphql`, `/_next/data/` in request URLs
- POST requests with JSON bodies (often richer than GET endpoints)
- Responses that contain more data than the page displays (API returns full product data, page shows subset)
- Pagination tokens or cursors in responses that differ from URL-based pagination

**If you find a GraphQL endpoint:**
Try introspection — it can map the entire data model in one query:
```bash
curl -s https://TARGET/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __schema { types { name fields { name type { name kind ofType { name } } } } } }"}'
```
If introspection is enabled, you get the full schema: all types, fields, and relationships. This tells you exactly what data is available and how to query it, often revealing fields the UI doesn't expose. Many production sites leave introspection on.

### Phase 4: The Probe — Can You Escape the Browser?

The browser is a recon tool, not the scraping tool. The goal of this phase is to take every interesting endpoint found in Phase 3 and test whether you can hit it without a browser at all. **The lightest working approach wins.**

**For each endpoint that carries target data:**

**Step 1 — Copy the exact request from the browser.**
From the network logs, extract the full request: URL, method, all headers, cookies, body (if POST).

**Step 2 — Replay it with curl.**
```bash
curl -s "https://TARGET/api/endpoint" \
  -H "User-Agent: Mozilla/5.0 ..." \
  -H "Accept: application/json" \
  -H "Cookie: session=abc123; ..." \
  # ... all headers from the browser request
```
Does it return the same data? If yes, you don't need a browser for scraping.

**Step 3 — Strip it down.**
Remove headers one by one. Remove cookies. Simplify. Find the **minimum viable request** — the smallest set of headers/cookies/params that still returns real data.

```bash
# Try bare minimum
curl -s "https://TARGET/api/endpoint"

# If that fails, add back headers incrementally
curl -s "https://TARGET/api/endpoint" -H "Accept: application/json"
curl -s "https://TARGET/api/endpoint" -H "Accept: application/json" -H "User-Agent: Mozilla/5.0 ..."
# ... keep adding until it works
```

**Step 4 — Classify the result.**

| Minimum viable request | Scraping stack |
|---|---|
| Bare curl, no headers | `curl` / `httpx` / `requests` — simplest possible |
| curl + User-Agent / Accept headers | `httpx` with custom headers — still trivial |
| curl + specific cookies from browser session | HTTP client + occasional browser session for cookie refresh |
| Only works in actual browser | Browser-based scraping (last resort) |

**Always prefer the lightest stack.** A headless browser is a heavy, slow, fragile dependency. If curl with two headers gets the same data, use that.

**If the endpoint needs cookies but curl works with them:**
The browser is only needed to *obtain* the session, not to *scrape*. Use browser once to get cookies, then scrape with HTTP client until cookies expire, then refresh. This is vastly cheaper than running a browser for every request.

### Phase 5: Anti-Bot Identification

Only relevant if the probe (Phase 4) fails or returns different data than the browser. If curl works, skip this.

**Detect bot protection by cookie signatures:**

| Cookie pattern | System |
|---|---|
| `_abck`, `bm_sz`, `bm_sv` | Akamai Bot Manager |
| `cf_clearance`, `__cf_bm` | Cloudflare |
| `datadome` | DataDome |
| `_px`, `_pxhd`, `_pxvid` | PerimeterX / HUMAN |
| `reese84` | Reese84 (Imperva) |
| `__qca` | Quantcast |

Also check response headers: `server: cloudflare`, `x-datadome`, `x-px-*`.

**If browser is unavoidable, pick the lightest option:**
- Headless Chrome → try first
- Headless Firefox → try if Chrome is blocked (different TLS/HTTP2 fingerprint, less targeted by detectors)
- Headed browser → last resort, some detectors check for headless signals

### Phase 6: Session & Authentication

If the site requires cookies/sessions:

1. **Extract cookies from browser session** — how many? What are the critical ones?
2. **Test cookie lifetime** — make a request, wait 30 min, try again. When do they expire?
3. **Identify refresh signals** — what status code / response body indicates expired session? (401, 403, redirect to login, empty response)
4. **Session scope** — can one session browse multiple categories/sections? Or does each section need its own session?
5. **Geo/locale** — does the site serve different content by region? How is region set? (cookie, URL path, query param, IP)

For authenticated content (behind login):
- What auth method? Cookie-based session? JWT? OAuth?
- Can you get a long-lived token?
- Does the API accept the same auth as the web UI?

### Phase 7: Pagination & Rate Limits

**Pagination discovery:**
- URL params: `?page=2`, `?offset=50`, `?cursor=abc123`
- Path segments: `/category/page/2`
- POST body params: `{"page": 2}`, `{"after": "cursor"}`
- Response fields: `next_page`, `has_more`, `total_pages`, `cursor`
- Link headers: `rel="next"`
- Infinite scroll: network requests triggered on scroll (capture these)

**Rate limits — infer before testing:**
- Check response headers first: `X-RateLimit-*`, `Retry-After`, `X-Rate-Limit-Remaining`
- Check API docs / developer portal if one exists
- Check robots.txt `Crawl-delay` directive
- Only probe empirically as a last resort, and gently — start slow (5s delays) and decrease. Aggressive probing can burn your IP or session before recon is complete.
- Some sites don't return explicit rate limit errors — they silently serve stale/empty data or redirect

### Phase 8: Synthesize & Report

After investigation, produce a scraping strategy report. Save to `docs/scraping-recon/TARGET.md` (or ask the user where if no obvious project context).

## Report Template

Scale the report to the findings. For simple targets (curl works, no auth, no bot detection), collapse to just Site Overview + Data Sources + Recommended Approach. Only expand sections that have meaningful content.

```markdown
# Scraping Recon: [TARGET DOMAIN]

Date: YYYY-MM-DD
Target URL(s): ...

## Site Overview
- Platform/framework: (Next.js, Shopify, custom, etc.)
- Content type: (e-commerce, news, directory, etc.)
- Scale: (estimated total pages/items from sitemap)
- ToS/legal notes: (any relevant restrictions found)

## Data Sources (ranked by preference)
1. **[Best source]** — e.g., "REST API at /api/products, returns JSON, no auth needed"
2. **[Fallback]** — e.g., "__NEXT_DATA__ JSON blob in page source"
3. **[Last resort]** — e.g., "DOM parsing of rendered page"

## Recommended Approach
- **Scraping stack**: [curl/httpx/browser — and why]
- **Entry points**: [sitemap, hardcoded URLs, search API]
- **Pagination**: [method + params]
- **Rate limiting**: [safe delay, max concurrency]
- **Session strategy**: [if needed — scope, lifetime, refresh]

## Anti-Bot (if applicable)
- **Protection**: [none / Cloudflare / Akamai / etc.]
- **Minimum viable request**: [what headers/cookies are actually needed]
- **Browser type**: [if browser needed — Chrome vs Firefox, headless vs headed]

## Data Shape
- Key fields available: [list]
- Sample response/element: [snippet]
- Gotchas: [multiple price formats, regional variants, etc.]

## Risks & Considerations
- [Rate limit unknowns, session expiry, geo-restrictions, legal, etc.]
```

## Key Principles

- **Simplest approach that works.** Never use a headless browser when curl will do. Never add headers you don't need. The minimum viable request is the goal.
- **APIs over HTML.** If the site has an API (discovered via network traffic), prefer it over DOM parsing. APIs are more stable, faster, and return structured data.
- **Check the source before the DOM.** Many frameworks embed complete data in the HTML source as JSON. Parsing a JSON blob is always better than scraping rendered HTML.
- **Every site is different.** No templates. Investigate each target fresh.
- **Document as you go.** Network findings, cookie structures, API shapes — capture them during investigation, not after.
