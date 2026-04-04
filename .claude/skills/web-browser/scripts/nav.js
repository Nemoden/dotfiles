#!/usr/bin/env node

import { connect } from "./cdp.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const args = process.argv.slice(2);
const url = args.find((a) => !a.startsWith("--"));
const newTab = args.includes("--new");
const tabArg = args.find((a) => a.startsWith("--tab="))?.slice(6);
const tabIdArg = args.find((a) => a.startsWith("--tab-id="))?.slice(9);

if (!url) {
  console.log("Usage: nav.js <url> [--new] [--tab=<url-pattern|index>] [--tab-id=<targetId>]");
  console.log("\nExamples:");
  console.log("  nav.js https://example.com                   # Navigate current (last) tab");
  console.log("  nav.js https://example.com --new             # Open in new tab, prints tab-id to stderr");
  console.log("  nav.js https://example.com --tab=bigw        # Navigate tab whose URL contains 'bigw'");
  console.log("  nav.js https://example.com --tab=0           # Navigate tab by index");
  console.log("  nav.js https://example.com --tab-id=<id>     # Navigate tab by exact targetId");
  process.exit(1);
}

// Global timeout
const globalTimeout = setTimeout(() => {
  console.error("✗ Global timeout exceeded (45s)");
  process.exit(1);
}, 45000);

try {
  log("connecting...");
  const cdp = await connect(5000);

  log("getting pages...");
  let targetId;

  if (newTab) {
    log("creating new tab...");
    const { targetId: newTargetId } = await cdp.send("Target.createTarget", {
      url: "about:blank",
    });
    targetId = newTargetId;
  } else {
    const pages = await cdp.getPages();
    let page;
    if (tabIdArg !== undefined) {
      page = pages.find((p) => p.targetId === tabIdArg);
    } else if (tabArg !== undefined) {
      const idx = parseInt(tabArg, 10);
      page = isNaN(idx)
        ? pages.find((p) => p.url.includes(tabArg))
        : pages[idx];
    } else {
      page = pages.at(-1);
    }
    if (!page) {
      console.error("✗ No matching tab found");
      process.exit(1);
    }
    targetId = page.targetId;
  }

  log("attaching to page...");
  const sessionId = await cdp.attachToPage(targetId);

  log("navigating...");
  await cdp.navigate(sessionId, url);

  if (newTab) {
    console.error("tab-id:", targetId);  // to stderr so it doesn't pollute stdout pipelines
    console.log("✓ Opened:", url, `[tab-id: ${targetId}]`);
  } else {
    console.log("✓ Navigated to:", url);
  }

  log("closing...");
  cdp.close();
  log("done");
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}
