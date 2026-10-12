#!/usr/bin/env node

// Load each URL in one tab, run an expression, print one JSON line per URL.
// Stops before the time budget runs out and prints how to resume.

import { readFileSync } from "node:fs";
import {
  StepError,
  currentProfile,
  evalCode,
  flag,
  loadSession,
  navigate,
  openTab,
  positional,
  resolveTab,
  run,
  sleep,
} from "./session.js";

const budget = (Number(flag("budget")) || 100) * 1000;

await run(
  async () => {
    const [expr, ...rest] = positional();
    const file = flag("urls-file");
    const fromFile = typeof file === "string" ? readFileSync(file, "utf8").split("\n") : [];
    const urls = [...rest, ...fromFile].map((u) => u.trim()).filter(Boolean);
    if (!expr || urls.length === 0) {
      throw new StepError("need an expression and at least one URL", "batch.js --tab=<name> '<expr>' <url> ...  or  --urls-file=<path>");
    }
    const wait = Number(flag("wait")) || 0;
    const skip = Number(flag("skip")) || 0;
    const start = Date.now();

    const tab = flag("tab");
    const noTabs = Object.keys(loadSession().tabs).length === 0;
    const t = tab === undefined && noTabs ? await openTab("batch", currentProfile()) : await resolveTab(tab);

    for (let i = skip; i < urls.length; i++) {
      const left = budget - (Date.now() - start);
      if (left < 5000) {
        console.log(JSON.stringify({ stopped: "time budget used", done: i, total: urls.length, next: `rerun with --skip=${i}` }));
        break;
      }
      const url = urls[i];
      try {
        await navigate(t.cdp, t.sessionId, url, Math.min(15000, left - 3000));
        if (wait) await sleep(wait);
        console.log(JSON.stringify({ url, result: await evalCode(t.cdp, t.sessionId, expr, { url }) }));
      } catch (e) {
        console.log(JSON.stringify({ url, error: e.message }));
      }
    }
    t.cdp.close();
  },
  { timeout: budget + 10000 },
);
