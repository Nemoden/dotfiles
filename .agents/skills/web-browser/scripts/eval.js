#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { StepError, evalCode, flag, positional, printValue, resolveTab, run } from "./session.js";

await run(async () => {
  let code = positional().join(" ");
  if (code === "-") code = readFileSync(0, "utf8");
  if (!code.trim()) {
    throw new StepError("no code given", "eval.js --tab=<name> 'document.title'  or  eval.js --tab=<name> - <<'JS' ... JS");
  }
  const t = await resolveTab(flag("tab"));
  printValue(await evalCode(t.cdp, t.sessionId, code));
  t.cdp.close();
});
