// Tells restore-agent-sessions which pi conversation runs in which tmux pane, because pi keeps no such record.
// ~/.pi/agent/extensions/restore-agent-sessions.ts links here; snapshot.py reads the records.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const dir = join(homedir(), ".cache", "restore-agent-sessions", "registry");
const record = join(dir, `pi-${process.pid}.json`);

export default function (pi: ExtensionAPI) {
  // Runs again after /new, /resume and /fork, so the record always names the open conversation.
  pi.on("session_start", async (_event, ctx) => {
    const sm = ctx.sessionManager;
    const pane = process.env.TMUX_PANE;
    const file = sm.getSessionFile();
    if (!pane || !file) return;
    mkdirSync(dir, { recursive: true });
    writeFileSync(record, JSON.stringify({ pid: process.pid, pane, sessionId: sm.getSessionId(), file, cwd: sm.getCwd() }));
  });
  pi.on("session_shutdown", async () => rmSync(record, { force: true }));
}
