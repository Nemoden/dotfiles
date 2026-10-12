#!/usr/bin/env node

import {
  StepError,
  currentProfile,
  flag,
  navigate,
  openTab,
  pageInfo,
  positional,
  resolveTab,
  run,
} from "./session.js";

await run(async () => {
  const url = positional()[0];
  if (!url) throw new StepError("no URL given", "nav.js <url> --new=<name>  or  nav.js <url> --tab=<name>");
  const timeout = Number(flag("timeout")) || 15000;
  const newName = flag("new");
  const t = newName !== undefined ? await openTab(newName, currentProfile()) : await resolveTab(flag("tab"));
  const { loaded } = await navigate(t.cdp, t.sessionId, url, timeout);
  const info = await pageInfo(t.cdp, t.sessionId);
  const state = loaded ? "loaded" : `still loading after ${timeout / 1000}s, usable`;
  console.log(`✓ ${t.name}: ${state}  ${info.url}  "${info.title}"`);
  t.cdp.close();
});
