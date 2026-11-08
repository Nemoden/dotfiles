#!/usr/bin/env node

// Read the network log of one named tab: list its requests, show one in full,
// or print one as a curl command. The logger must run (start.js --watch).

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { STATE_ROOT, StepError, flag, loadSession, run, slug } from "./session.js";

/**
 * One request of the tab, built from the log lines that share its requestId.
 *
 * n        Number shown to the agent. It follows log order, so it stays the
 *          same between calls while the log grows.
 * headers  The headers Chrome sent, with Cookie, lower-case names.
 * status   HTTP status, "redirect <code>" for a hop, "failed: <error>", or null.
 */
class Request {
  constructor(n, r) {
    this.n = n;
    this.method = r.method;
    this.url = r.url;
    this.type = r.resourceType;
    this.headers = lower(r.headers);
    this.postData = r.postData;
    this.status = null;
    this.mime = null;
    this.responseHeaders = {};
    this.bodyFile = null;
  }
}

const lower = (h = {}) => Object.fromEntries(Object.entries(h).map(([k, v]) => [k.toLowerCase(), v]));

function tabRequests(name) {
  const tab = loadSession().tabs[name];
  if (!tab) {
    const names = Object.keys(loadSession().tabs);
    throw new StepError(`no tab "${name}" in this session`, names.length ? `use one of: ${names.join(", ")}` : "open one: nav.js <url> --new=<name>");
  }
  const root = join(STATE_ROOT, "logs", slug(tab.profile));
  const files = existsSync(root)
    ? readdirSync(root).filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d)).sort().map((d) => join(root, d, `${tab.id}.jsonl`)).filter(existsSync)
    : [];
  if (!files.length) {
    throw new StepError(
      `no network log for tab "${name}"`,
      `start the logger before the page loads: start.js --watch, then reload: nav.js <url> --tab=${name}`,
    );
  }

  const list = [];
  const byId = new Map();
  for (const file of files) {
    for (const line of readFileSync(file, "utf8").split("\n")) {
      let e;
      try {
        e = JSON.parse(line);
      } catch {
        continue;
      }
      const r = byId.get(e.requestId);
      if (e.type === "network.request") {
        // A redirect reuses the requestId: the old hop ends, a new one starts.
        if (r && e.redirectStatus) r.status = `redirect ${e.redirectStatus}`;
        const next = new Request(list.length + 1, e);
        list.push(next);
        byId.set(e.requestId, next);
      } else if (!r) {
        continue;
      } else if (e.type === "network.requestHeaders") {
        // Extra-info headers can arrive per hop; they belong to the newest one.
        r.headers = { ...r.headers, ...lower(e.headers) };
      } else if (e.type === "network.postData") {
        r.postData = e.postData;
      } else if (e.type === "network.response") {
        r.status = e.status;
        r.mime = e.mimeType;
        r.responseHeaders = e.headers || {};
      } else if (e.type === "network.failure") {
        r.status = `failed: ${e.errorText}`;
      } else if (e.type === "network.body") {
        r.bodyFile = e.file;
      }
    }
  }
  return list;
}

function pick(list, n) {
  const r = list[Number(n) - 1];
  if (!r) throw new StepError(`no request ${n}`, `pick a number from the list: net.js --tab=${flag("tab")}`);
  return r;
}

const q = (s) => `'${String(s).replaceAll("'", `'\\''`)}'`;
// curl sets these itself, or they are HTTP/2 fields, not headers.
const NOT_FOR_CURL = new Set(["host", "content-length", "connection", "accept-encoding"]);

function toCurl(r) {
  const parts = [`curl -sS ${q(r.url)}`];
  if (r.method !== "GET") parts.push(`-X ${r.method}`);
  for (const [k, v] of Object.entries(r.headers)) {
    if (!k.startsWith(":") && !NOT_FOR_CURL.has(k)) parts.push(`-H ${q(`${k}: ${v}`)}`);
  }
  if (r.postData != null) parts.push(`--data-raw ${q(r.postData)}`);
  if (r.headers["accept-encoding"]) parts.push("--compressed");
  return parts.join(" \\\n  ");
}

function printHeaders(title, h) {
  console.log(`${title}:`);
  for (const [k, v] of Object.entries(h)) console.log(`  ${k}: ${v}`);
}

const SHOW_MAX = 20000;
const API_TYPES = new Set(["Document", "XHR", "Fetch", null, undefined]);

await run(async () => {
  const name = flag("tab");
  if (typeof name !== "string") throw new StepError("no tab given", "add --tab=<name>. tabs.js lists your tabs.");
  const list = tabRequests(name);

  if (flag("curl") !== undefined) {
    const r = pick(list, flag("curl"));
    console.log(toCurl(r));
    if (r.headers.cookie || r.headers.authorization) console.error("note: this command holds the user's cookies or auth token. Do not paste it into tickets, docs or chats.");
    return;
  }

  if (flag("show") !== undefined) {
    const r = pick(list, flag("show"));
    console.log(`#${r.n}  ${r.method}  ${r.status ?? "no response"}  ${r.type ?? ""}`);
    console.log(r.url);
    printHeaders("request headers", r.headers);
    if (r.postData != null) console.log(`request body:\n${r.postData}`);
    printHeaders("response headers", r.responseHeaders);
    if (r.bodyFile && existsSync(r.bodyFile)) {
      const body = readFileSync(r.bodyFile, "utf8");
      const cut = body.length > SHOW_MAX ? `\n... ${body.length - SHOW_MAX} more characters` : "";
      console.log(`response body (${r.mime}, full file: ${r.bodyFile}):\n${body.slice(0, SHOW_MAX)}${cut}`);
    } else {
      console.log(`response body: not saved (only JSON, XML, HTML and plain text up to 2 MB are saved)`);
    }
    return;
  }

  const grep = typeof flag("grep") === "string" ? flag("grep") : null;
  const shown = list.filter((r) => (flag("all") || API_TYPES.has(r.type)) && (!grep || r.url.includes(grep)));
  for (const r of shown) {
    const url = r.url.length > 160 ? `${r.url.slice(0, 159)}…` : r.url;
    console.log(`${String(r.n).padStart(4)}  ${r.method.padEnd(6)} ${String(r.status ?? "...").padEnd(4)} ${(r.type ?? "").padEnd(8)} ${url}`);
  }
  const hidden = flag("all") ? "" : " Scripts, styles and images are hidden: add --all.";
  console.log(`${shown.length} of ${list.length} requests.${hidden} One in full: net.js --tab=${name} --show=<n>. As curl: --curl=<n>`);
});
