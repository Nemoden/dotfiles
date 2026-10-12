#!/usr/bin/env node

// Quit one agent browser. Refuses while other sessions still have tabs in it.
// The user's daily Chrome cannot be reached from here.

import {
  DEFAULT_PROFILE,
  StepError,
  connectProfile,
  flag,
  loadSession,
  otherSessionsUsing,
  run,
} from "./session.js";

await run(async () => {
  const profile = typeof flag("profile") === "string" ? flag("profile") : loadSession().profile || DEFAULT_PROFILE;
  const cdp = await connectProfile(profile);
  const live = new Set((await cdp.getPages()).map((p) => p.targetId));
  const others = otherSessionsUsing(profile, live);
  if (others.length && !flag("force")) {
    cdp.close();
    throw new StepError(
      `other sessions still use agent browser "${profile}": ${others.map((s) => s.slice(0, 8)).join(", ")}`,
      "close only your own tabs: tabs.js --close-all",
    );
  }
  await cdp.send("Browser.close").catch(() => {});
  console.log(`✓ agent browser "${profile}" closed`);
});
