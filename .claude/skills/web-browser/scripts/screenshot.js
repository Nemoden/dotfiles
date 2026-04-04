#!/usr/bin/env node

import { tmpdir } from "node:os";
import { join } from "node:path";
import { writeFileSync } from "node:fs";
import { connect } from "./cdp.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const tabArg = process.argv.find((a) => a.startsWith("--tab="))?.slice(6);
const tabIdArg = process.argv.find((a) => a.startsWith("--tab-id="))?.slice(9);

// Global timeout
const globalTimeout = setTimeout(() => {
  console.error("✗ Global timeout exceeded (15s)");
  process.exit(1);
}, 15000);

try {
  log("connecting...");
  const cdp = await connect(5000);

  log("getting pages...");
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

  log("attaching to page...");
  const sessionId = await cdp.attachToPage(page.targetId);

  log("taking screenshot...");
  const data = await cdp.screenshot(sessionId);

  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const filename = `screenshot-${timestamp}.png`;
  const filepath = join(tmpdir(), filename);

  writeFileSync(filepath, data);
  console.log(filepath);

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
