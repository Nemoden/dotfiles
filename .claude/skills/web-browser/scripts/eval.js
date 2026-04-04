#!/usr/bin/env node

import { connect } from "./cdp.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const rawArgs = process.argv.slice(2);
const tabArg = rawArgs.find((a) => a.startsWith("--tab="))?.slice(6);
const tabIdArg = rawArgs.find((a) => a.startsWith("--tab-id="))?.slice(9);
const codeArgs = rawArgs.filter((a) => !a.startsWith("--tab=") && !a.startsWith("--tab-id="));
const code = codeArgs.join(" ");

if (!code) {
  console.log("Usage: eval.js [--tab=<url-pattern|index>] [--tab-id=<targetId>] 'code'");
  console.log("\nExamples:");
  console.log('  eval.js "document.title"');
  console.log("  eval.js --tab-id=ABCD1234 'document.title'  # unambiguous tab by targetId");
  console.log("  eval.js --tab=0 'document.title'            # evaluate in tab by index");
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

  log("evaluating...");
  const expression = `(async () => { return (${code}); })()`;
  const result = await cdp.evaluate(sessionId, expression);

  log("formatting result...");
  if (Array.isArray(result)) {
    for (let i = 0; i < result.length; i++) {
      if (i > 0) console.log("");
      for (const [key, value] of Object.entries(result[i])) {
        console.log(`${key}: ${value}`);
      }
    }
  } else if (typeof result === "object" && result !== null) {
    for (const [key, value] of Object.entries(result)) {
      console.log(`${key}: ${value}`);
    }
  } else {
    console.log(result);
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
