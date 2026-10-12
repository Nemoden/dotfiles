#!/usr/bin/env node

// Start the agent browser for one profile, or reuse it if it already runs.
// It runs from its own data folder, so the user's daily Chrome is never
// started, stopped or written to.

import { execFileSync, spawn } from "node:child_process";
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  DAILY_ROOT,
  DEFAULT_PROFILE,
  StepError,
  browserPort,
  dataDir,
  flag,
  run,
  sleep,
  updateSession,
} from "./session.js";

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

if (flag("help")) {
  console.log(`Usage: start.js [--profile=<name>] [--headless] [--watch]

  --profile=<name>  Agent browser identity (default ${DEFAULT_PROFILE}). At each cold start,
                    the logins (cookies, local storage) of the daily Chrome profile with
                    that name, folder or email are copied in. No match: empty profile.
  --headless        No window.
  --watch           Also log console and network of the agent browser (watch.js).`);
  process.exit(0);
}

const profile = typeof flag("profile") === "string" ? flag("profile") : DEFAULT_PROFILE;

/** Find a daily Chrome profile by display name, folder name or email. */
function findDailyProfile(name) {
  let cache = {};
  try {
    cache = JSON.parse(readFileSync(join(DAILY_ROOT, "Local State"), "utf8")).profile.info_cache;
  } catch {}
  const all = Object.entries(cache).map(([dir, info]) => ({ dir, name: info.name, email: info.user_name || "" }));
  const want = name.toLowerCase();
  const hit = all.find((p) => [p.dir, p.name, p.email].some((v) => v && v.toLowerCase() === want));
  return { hit, all };
}

/** Copy the files that hold logins. Saved passwords are not copied. */
function copyLogins(src, dst) {
  mkdirSync(dst, { recursive: true, mode: 0o700 });
  const cookies = join(src, "Cookies");
  if (existsSync(cookies)) {
    rmSync(join(dst, "Cookies"), { force: true });
    rmSync(join(dst, "Cookies-journal"), { force: true });
    // sqlite3 makes a consistent copy while the daily Chrome keeps the file open.
    execFileSync("sqlite3", [`file:${cookies}?mode=ro`, `.backup '${join(dst, "Cookies")}'`]);
  }
  const storage = join(src, "Local Storage");
  if (existsSync(storage)) {
    rmSync(join(dst, "Local Storage"), { recursive: true, force: true });
    cpSync(storage, join(dst, "Local Storage"), { recursive: true, filter: (p) => !p.endsWith("/LOCK") });
  }
}

await run(
  async () => {
    const dir = dataDir(profile);
    const running = await browserPort(profile);
    if (running) {
      updateSession((s) => (s.profile = profile));
      console.log(`✓ agent browser "${profile}" already running (port ${running}). This session uses it now.`);
      return;
    }

    const { hit, all } = findDailyProfile(profile);
    if (hit) {
      copyLogins(join(DAILY_ROOT, hit.dir), join(dir, "Default"));
      console.log(`✓ copied logins from your Chrome profile "${hit.name}" (${hit.dir})`);
    } else {
      const known = all.map((p) => `"${p.name}"`).join(", ");
      console.log(`note: no daily Chrome profile "${profile}" (you have: ${known}). Using agent profile as is.`);
    }

    mkdirSync(dir, { recursive: true, mode: 0o700 });
    rmSync(join(dir, "DevToolsActivePort"), { force: true });
    const args = [
      `--user-data-dir=${dir}`,
      "--profile-directory=Default",
      "--remote-debugging-port=0",
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-search-engine-choice-screen",
      "--disable-features=ProfilePicker",
    ];
    if (flag("headless")) args.push("--headless=new");
    spawn(CHROME, [...args, "about:blank"], { detached: true, stdio: "ignore" }).unref();

    let port = null;
    for (let i = 0; i < 40 && !port; i++) {
      await sleep(500);
      port = await browserPort(profile);
    }
    if (!port) {
      throw new StepError(`agent browser "${profile}" did not start within 20s`, "tell the user. Do not kill or restart Chrome.");
    }
    updateSession((s) => (s.profile = profile));

    if (flag("watch")) {
      const watcher = join(dirname(fileURLToPath(import.meta.url)), "watch.js");
      spawn(process.execPath, [watcher, `--profile=${profile}`], { detached: true, stdio: "ignore" }).unref();
    }
    console.log(`✓ agent browser "${profile}" started (port ${port}). Your daily Chrome is untouched.`);
  },
  { tabs: false },
);
