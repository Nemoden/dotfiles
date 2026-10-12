#!/usr/bin/env node

// End-to-end check of every documented command. It runs a headless agent
// browser on a throwaway profile against a local test server, and fails if
// the user's daily Chrome processes change.

import { execFileSync, spawn } from "node:child_process";
import { readFileSync, rmSync } from "node:fs";
import { createServer } from "node:http";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { connect } from "./cdp.js";
import { STATE_ROOT, browserPort, dataDir } from "./session.js";

const DIR = dirname(fileURLToPath(import.meta.url));
const PROFILE = "selftest";
const ME = `selftest-${process.pid}`;
const OTHER = `selftest-other-${process.pid}`;

const server = createServer((req, res) => {
  if (req.url === "/slow-img") return setTimeout(() => res.end(), 4000);
  const slow = req.url === "/slow" ? '<img src="/slow-img">' : "";
  res.setHeader("content-type", "text/html");
  res.end(`<title>Page ${req.url}</title><h1>${req.url}</h1>${slow}`);
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const BASE = `http://127.0.0.1:${server.address().port}`;

// Async on purpose: the test server lives in this process and must keep answering.
function sh(script, args = [], { session = ME, input = "" } = {}) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, [join(DIR, script), ...args], {
      env: { ...process.env, CLAUDE_CODE_SESSION_ID: session },
    });
    let out = "";
    let err = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    child.on("close", (code) => resolve({ code, out, err }));
    child.stdin.end(input);
  });
}

function json(text) {
  try {
    return JSON.stringify(JSON.parse(text));
  } catch {
    return null;
  }
}

let failed = 0;
function check(label, ok, r) {
  console.log(`${ok ? "ok  " : "FAIL"}  ${label}`);
  if (!ok) {
    failed++;
    if (r) console.log(`      stdout: ${r.out.trim()}\n      stderr: ${r.err.trim()}`);
  }
}

function dailyChromePids() {
  const ps = execFileSync("ps", ["-axo", "pid=,command="], { encoding: "utf8" });
  return ps
    .split("\n")
    .filter((l) => l.includes("MacOS/Google Chrome") && !l.includes("Helper") && !l.includes("--user-data-dir="))
    .map((l) => l.trim().split(" ")[0])
    .sort()
    .join(",");
}

const before = dailyChromePids();
let r;

try {
  r = await sh("start.js", [`--profile=${PROFILE}`, "--headless"]);
  check("start: starts the agent browser", r.code === 0 && r.out.includes("started"), r);
  r = await sh("start.js", [`--profile=${PROFILE}`, "--headless"]);
  check("start: second call reuses it", r.code === 0 && r.out.includes("already running"), r);

  r = await sh("eval.js", ["document.title"]);
  check("eval with no tabs: error names the next step", r.code === 1 && r.err.includes("no tabs") && r.err.includes("next:"), r);

  r = await sh("nav.js", [`${BASE}/p/1`, "--new=one"]);
  check("nav --new=one: waits for load", r.code === 0 && r.out.includes("✓ one: loaded") && r.out.includes("Page /p/1"), r);
  r = await sh("nav.js", [`${BASE}/p/2`, "--new"]);
  check("nav --new: auto name t1", r.code === 0 && r.out.includes("✓ t1: loaded"), r);
  check("footer lists both tabs on stderr", /one .*\/p\/1/.test(r.err) && /\*t1 .*\/p\/2/.test(r.err), r);
  r = await sh("nav.js", [`${BASE}/p/9`, "--new=one"]);
  check("nav --new with a live name: refused", r.code === 1 && r.err.includes("already exists"), r);

  r = await sh("eval.js", ["document.title"]);
  check("eval without --tab when 2 tabs: asks which", r.code === 1 && r.err.includes("one, t1"), r);
  r = await sh("eval.js", ["--tab=one", "document.title"]);
  check("eval expression", r.out.trim() === "Page /p/1", r);
  r = await sh("eval.js", ["--tab=one", "document.title;"]);
  check("eval expression with trailing semicolon", r.out.trim() === "Page /p/1", r);
  r = await sh("eval.js", ["--tab=one", "const x = 2; return x * 3"]);
  check("eval function body with return", r.out.trim() === "6", r);
  r = await sh("eval.js", ["--tab=one", '["ab", { k: [1] }]']);
  check("eval prints arrays and objects as JSON", json(r.out) === '["ab",{"k":[1]}]', r);
  r = await sh("eval.js", ["--tab=one", "-"], { input: "return location.pathname" });
  check("eval reads code from stdin with -", r.out.trim() === "/p/1", r);
  r = await sh("eval.js", ["--tab=onee", "1"]);
  check("eval unknown tab: lists real names", r.code === 1 && r.err.includes('no tab "onee"') && r.err.includes("one, t1"), r);

  r = await sh("nav.js", [`${BASE}/p/3`, "--tab=one"]);
  check("nav --tab reuses the tab", r.code === 0 && r.out.includes("Page /p/3"), r);
  r = await sh("nav.js", [`${BASE}/slow`, "--tab=one", "--timeout=1000"]);
  check("nav timeout: reports still loading", r.code === 0 && r.out.includes("still loading"), r);
  r = await sh("nav.js", ["http://no-such-host.invalid/", "--tab=t1"]);
  check("nav to bad host: clear error", r.code === 1 && r.err.includes("navigation to") && r.err.includes("failed"), r);

  r = await sh("batch.js", ["--tab=t1", "[document.title, url]", `${BASE}/p/4`, `${BASE}/p/5`]);
  const last = JSON.parse(json(r.out.trim().split("\n").at(-1)) ?? "{}");
  const ok = r.out.trim().split("\n").length === 2 && last.result?.[0] === "Page /p/5" && last.result?.[1].endsWith("/p/5");
  check("batch: one JSON line per URL, url is bound", ok, r);
  r = await sh("batch.js", ["--tab=t1", "--budget=6", "1", `${BASE}/slow`, `${BASE}/slow`, `${BASE}/slow`]);
  check("batch: stops inside the time budget and says how to resume", r.out.includes("--skip="), r);

  r = await sh("screenshot.js", ["--tab=one"]);
  const png = r.code === 0 ? readFileSync(r.out.trim()).subarray(1, 4).toString() : "";
  check("screenshot writes a PNG", png === "PNG", r);

  r = await sh("dismiss-cookies.js", ["--tab=one"]);
  check("dismiss-cookies runs on the named tab", r.code === 0 && r.out.includes("No cookie dialog"), r);

  r = await sh("eval.js", ["--tab=one", "1"], { session: OTHER });
  check("another session cannot use this session's tab", r.code === 1 && r.err.includes('no tab "one"'), r);
  r = await sh("nav.js", [`${BASE}/p/6`, "--new=x", `--profile=${PROFILE}`], { session: OTHER });
  check("another session opens its own tab", r.code === 0, r);
  r = await sh("stop.js", [`--profile=${PROFILE}`]);
  check("stop: refused while another session has tabs", r.code === 1 && r.err.includes("other sessions still use"), r);
  r = await sh("tabs.js", ["--close-all"], { session: OTHER });
  check("tabs --close-all closes only own tabs", r.code === 0 && r.out.includes("closed x") && r.err.includes("(none)"), r);

  const cdp = await connect(await browserPort(PROFILE));
  const t1 = JSON.parse(readFileSync(join(STATE_ROOT, "sessions", `${ME}.json`), "utf8")).tabs.t1.id;
  await cdp.send("Target.closeTarget", { targetId: t1 });
  cdp.close();
  r = await sh("eval.js", ["--tab=t1", "1"]);
  check("tab closed by the user: reported and removed", r.code === 1 && r.err.includes('tab "t1" was closed'), r);

  r = await sh("tabs.js", ["--close=one"]);
  check("tabs --close=one", r.code === 0 && r.out.includes("closed one") && r.err.includes("(none)"), r);

  r = await sh("stop.js", [`--profile=${PROFILE}`]);
  check("stop: closes the agent browser", r.code === 0 && r.out.includes("closed"), r);
  await new Promise((res) => setTimeout(res, 1500));
  r = await sh("nav.js", [`${BASE}/p/7`, "--new=y", `--profile=${PROFILE}`]);
  check("after stop: error says run start.js", r.code === 1 && r.err.includes("start.js"), r);
} finally {
  const port = await browserPort(PROFILE);
  if (port) {
    const c = await connect(port);
    await c.send("Browser.close").catch(() => {});
  }
  server.close();
  await new Promise((res) => setTimeout(res, 1000));
  rmSync(dataDir(PROFILE), { recursive: true, force: true });
  for (const id of [ME, OTHER]) rmSync(join(STATE_ROOT, "sessions", `${id}.json`), { force: true });
}

check("daily Chrome processes unchanged", dailyChromePids() === before);
console.log(failed ? `\n${failed} check(s) failed` : "\nall checks passed");
process.exit(failed ? 1 : 0);
