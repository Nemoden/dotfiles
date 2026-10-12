/**
 * Shared state for the web-browser scripts.
 *
 * Profile   An agent browser identity, e.g. "AGENTS" or "Kirill". Each one is a
 *           separate Chrome data folder under DATA_ROOT, never the user's
 *           daily Chrome folder, so the scripts can never touch daily Chrome.
 * Session   One Claude Code session (CLAUDE_CODE_SESSION_ID, set in every Bash
 *           call). Its file lists the tabs it owns: { profile, last, tabs }.
 *           tabs maps a name the agent chose to { id: CDP targetId, profile }.
 *           Scripts act only on tabs in this list.
 */

import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { connect } from "./cdp.js";

const HOME = homedir();
export const DATA_ROOT = join(HOME, ".local/share/web-browser");
export const STATE_ROOT = join(HOME, ".cache/web-browser");
export const DAILY_ROOT = join(HOME, "Library/Application Support/Google/Chrome");
export const DEFAULT_PROFILE = "AGENTS";

const SESSION_DIR = join(STATE_ROOT, "sessions");
export const SESSION_ID = process.env.CLAUDE_CODE_SESSION_ID || "manual";

/** An error that also tells the agent the exact next step. */
export class StepError extends Error {
  constructor(message, next) {
    super(message);
    this.next = next;
  }
}

/** `--name=value` gives "value", a bare `--name` gives true, absent gives undefined. */
export function flag(name) {
  for (const a of process.argv.slice(2)) {
    if (a === `--${name}`) return true;
    if (a.startsWith(`--${name}=`)) return a.slice(name.length + 3);
  }
  return undefined;
}

export function positional() {
  return process.argv.slice(2).filter((a) => !a.startsWith("--"));
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export function slug(profile) {
  return profile.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

export function dataDir(profile) {
  return join(DATA_ROOT, slug(profile));
}

/** Port of the running agent browser for this profile, or null. */
export async function browserPort(profile) {
  let port;
  try {
    port = Number(readFileSync(join(dataDir(profile), "DevToolsActivePort"), "utf8").split("\n")[0]);
  } catch {
    return null;
  }
  try {
    const r = await fetch(`http://127.0.0.1:${port}/json/version`, { signal: AbortSignal.timeout(2000) });
    return r.ok ? port : null;
  } catch {
    return null;
  }
}

export async function connectProfile(profile) {
  const port = await browserPort(profile);
  if (!port) {
    const opt = profile === DEFAULT_PROFILE ? "" : ` --profile="${profile}"`;
    throw new StepError(
      `agent browser "${profile}" is not running`,
      `run start.js${opt}. It starts only the agent browser. Never start, quit or kill Chrome yourself.`,
    );
  }
  return connect(port);
}

function sessionPath(id = SESSION_ID) {
  return join(SESSION_DIR, `${id}.json`);
}

export function loadSession(id = SESSION_ID) {
  try {
    return JSON.parse(readFileSync(sessionPath(id), "utf8"));
  } catch {
    return { profile: DEFAULT_PROFILE, last: null, tabs: {} };
  }
}

/** Read, change and atomically write this session's file. */
export function updateSession(change) {
  mkdirSync(SESSION_DIR, { recursive: true, mode: 0o700 });
  const s = loadSession();
  change(s);
  const tmp = `${sessionPath()}.${process.pid}`;
  writeFileSync(tmp, JSON.stringify(s, null, 2));
  renameSync(tmp, sessionPath());
  return s;
}

/** Profile for new tabs: --profile, else the one start.js picked for this session. */
export function currentProfile() {
  const f = flag("profile");
  return typeof f === "string" ? f : loadSession().profile || DEFAULT_PROFILE;
}

/** Ids of other sessions that own a live tab in this browser. */
export function otherSessionsUsing(profile, liveIds) {
  if (!existsSync(SESSION_DIR)) return [];
  return readdirSync(SESSION_DIR)
    .filter((f) => f.endsWith(".json") && f !== `${SESSION_ID}.json`)
    .map((f) => f.slice(0, -5))
    .filter((id) => Object.values(loadSession(id).tabs).some((t) => t.profile === profile && liveIds.has(t.id)));
}

/** Connect to a tab this session owns. With no name, use the only tab there is. */
export async function resolveTab(name) {
  const session = loadSession();
  const names = Object.keys(session.tabs);
  if (typeof name !== "string") {
    if (names.length === 0) throw new StepError("this session has no tabs", "open one: nav.js <url> --new=<name>");
    if (names.length > 1) {
      throw new StepError(`this session has ${names.length} tabs, say which one`, `add --tab=<name>, one of: ${names.join(", ")}`);
    }
    name = names[0];
  }
  const tab = session.tabs[name];
  if (!tab) {
    const known = names.length ? `use one of: ${names.join(", ")}, or ` : "";
    throw new StepError(`no tab "${name}" in this session`, `${known}open it: nav.js <url> --new=${name}`);
  }
  const cdp = await connectProfile(tab.profile);
  const pages = await cdp.getPages();
  if (!pages.some((p) => p.targetId === tab.id)) {
    cdp.close();
    updateSession((s) => delete s.tabs[name]);
    throw new StepError(`tab "${name}" was closed, so it is removed from this session`, `open it again: nav.js <url> --new=${name}`);
  }
  const sessionId = await cdp.attachToPage(tab.id);
  updateSession((s) => (s.last = name));
  return { cdp, sessionId, name };
}

/** Create a new tab in the profile's agent browser and record it under `name`. */
export async function openTab(name, profile) {
  const session = loadSession();
  if (typeof name !== "string") {
    let i = 1;
    while (session.tabs[`t${i}`]) i++;
    name = `t${i}`;
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(name)) {
    throw new StepError(`bad tab name "${name}"`, "use letters, digits, - or _, for example --new=ebay");
  }
  const cdp = await connectProfile(profile);
  const old = session.tabs[name];
  if (old && (await cdp.getPages()).some((p) => p.targetId === old.id)) {
    cdp.close();
    throw new StepError(`tab "${name}" already exists in this session`, `reuse it with --tab=${name}, or pick another name`);
  }
  const { targetId } = await cdp.send("Target.createTarget", { url: "about:blank" });
  updateSession((s) => {
    s.tabs[name] = { id: targetId, profile };
    s.last = name;
  });
  const sessionId = await cdp.attachToPage(targetId);
  return { cdp, sessionId, name };
}

/** Navigate and wait for the load event. Returns { loaded: false } on timeout. */
export async function navigate(cdp, sessionId, url, timeout = 15000) {
  await cdp.send("Page.enable", {}, sessionId);
  const loaded = cdp.waitFor("Page.loadEventFired", sessionId, timeout);
  const res = await cdp.send("Page.navigate", { url }, sessionId, timeout);
  if (res.errorText) throw new StepError(`navigation to ${url} failed: ${res.errorText}`, "check the URL; the tab stays open");
  // A same-document navigation (only the #hash changes) fires no load event.
  return { loaded: res.loaderId ? (await loaded) !== null : true };
}

export function pageInfo(cdp, sessionId) {
  return cdp.evaluate(sessionId, "({ url: location.href, title: document.title })", 5000);
}

/**
 * Run user code in the page. The code can be an expression ("document.title")
 * or a function body with `return`. `vars` become parameters, e.g. { url }.
 */
export async function evalCode(cdp, sessionId, code, vars = {}, timeout = 30000) {
  const params = Object.keys(vars).join(", ");
  const args = Object.values(vars).map((v) => JSON.stringify(v)).join(", ");
  const run = (body) =>
    cdp.send(
      "Runtime.evaluate",
      { expression: `(async (${params}) => { ${body}\n })(${args})`, returnByValue: true, awaitPromise: true },
      sessionId,
      timeout,
    );
  const expr = code.trim().replace(/;+$/, "");
  let r = await run(`return (${expr}\n);`);
  // A syntax error happens before any code runs, so a second try is safe.
  if (r.exceptionDetails?.exception?.className === "SyntaxError") r = await run(code);
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
  return r.result?.value;
}

export function printValue(v) {
  if (typeof v === "string") console.log(v);
  else console.log(v === undefined ? "undefined" : JSON.stringify(v, null, 2));
}

const cut = (s, n) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);

/** Print this session's live tabs to stderr, and drop the ones that are gone. */
export async function printTabs() {
  const session = loadSession();
  const byProfile = {};
  for (const [name, t] of Object.entries(session.tabs)) (byProfile[t.profile] ??= []).push(name);

  const lines = [];
  const gone = [];
  for (const [profile, names] of Object.entries(byProfile)) {
    let pages = [];
    const port = await browserPort(profile);
    if (port) {
      try {
        const cdp = await connect(port);
        pages = await cdp.getPages();
        cdp.close();
      } catch {}
    }
    for (const name of names) {
      const page = pages.find((p) => p.targetId === session.tabs[name].id);
      if (!page) {
        gone.push(name);
        continue;
      }
      const mark = session.last === name ? "*" : " ";
      lines.push(`  ${mark}${name}  [${profile}]  ${cut(page.url, 100)}  "${cut(page.title, 60)}"`);
    }
  }
  if (gone.length) updateSession((s) => gone.forEach((n) => delete s.tabs[n]));

  console.error(`--- tabs of this session (${SESSION_ID.slice(0, 8)}):`);
  if (lines.length) console.error(lines.join("\n"));
  else console.error("  (none)");
  if (gone.length) console.error(`  closed and removed: ${gone.join(", ")}`);
}

/** Run a script body: hard time limit, errors with a next step, then the tab list. */
export async function run(main, { timeout = 45000, tabs = true } = {}) {
  const timer = setTimeout(() => {
    console.error(`✗ timed out after ${timeout / 1000}s`);
    process.exit(1);
  }, timeout);
  let code = 0;
  try {
    await main();
  } catch (e) {
    code = 1;
    console.error(`✗ ${e.message}`);
    if (e.next) console.error(`next: ${e.next}`);
  }
  if (tabs) {
    try {
      await printTabs();
    } catch {}
  }
  clearTimeout(timer);
  process.exit(code);
}
