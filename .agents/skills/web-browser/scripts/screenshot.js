#!/usr/bin/env node

import { writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { flag, resolveTab, run } from "./session.js";

await run(async () => {
  const t = await resolveTab(flag("tab"));
  const data = await t.cdp.screenshot(t.sessionId);
  const file = join(tmpdir(), `screenshot-${t.name}-${Date.now()}.png`);
  writeFileSync(file, data);
  console.log(file);
  t.cdp.close();
});
