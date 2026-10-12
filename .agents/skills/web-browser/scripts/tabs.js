#!/usr/bin/env node

// With no option, print this session's tabs. --close=a,b or --close-all closes them.

import { StepError, connectProfile, flag, loadSession, run, updateSession } from "./session.js";

await run(async () => {
  const close = flag("close");
  if (close === undefined && !flag("close-all")) return;
  const tabs = loadSession().tabs;
  const names = flag("close-all") ? Object.keys(tabs) : String(close).split(",");
  for (const name of names) {
    const t = tabs[name];
    if (!t) throw new StepError(`no tab "${name}" in this session`, "run tabs.js to see your tabs");
    try {
      const cdp = await connectProfile(t.profile);
      await cdp.send("Target.closeTarget", { targetId: t.id });
      cdp.close();
    } catch {}
    updateSession((s) => delete s.tabs[name]);
    console.log(`✓ closed ${name}`);
  }
});
