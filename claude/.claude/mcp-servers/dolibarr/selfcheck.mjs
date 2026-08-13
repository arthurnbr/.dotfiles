#!/usr/bin/env node
// Protocol self-check for the Dolibarr MCP server. Machine-agnostic: it verifies
// the JSON-RPC/MCP handshake and tool advertising, NOT the live Dolibarr API
// (so it passes whether or not ~/.secrets/dolibarr.env is present).
//   Run:  node selfcheck.mjs   (exit 0 = ok)

import { spawn } from "node:child_process";
import { join } from "node:path";

const server = join(import.meta.dirname, "server.mjs");
const p = spawn(process.execPath, [server], { stdio: ["pipe", "pipe", "inherit"] });
let out = "";
p.stdout.setEncoding("utf8");
p.stdout.on("data", (d) => (out += d));

const send = (o) => p.stdin.write(JSON.stringify(o) + "\n");
send({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "selfcheck", version: "0" } } });
send({ jsonrpc: "2.0", method: "notifications/initialized" });
send({ jsonrpc: "2.0", id: 2, method: "tools/list" });
send({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "dolibarr_get", arguments: { path: "/status" } } });
send({ jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "does_not_exist", arguments: {} } });

await new Promise((r) => setTimeout(r, 1500));
p.kill();

const msgs = out.trim().split("\n").filter(Boolean).map((l) => JSON.parse(l));
const byId = (id) => msgs.find((m) => m.id === id);
const init = byId(1);
const list = byId(2);
const call = byId(3);
const bad = byId(4);

let failed = 0;
const check = (cond, label) => {
  console.error(`${cond ? "ok  " : "FAIL"}  ${label}`);
  if (!cond) failed++;
};

check(init?.result?.serverInfo?.name === "dolibarr", "initialize → serverInfo.name=dolibarr");
check(typeof init?.result?.protocolVersion === "string", "initialize → protocolVersion echoed");
check(!msgs.some((m) => m.id === undefined && m.result), "notification 'initialized' → no reply");
check(Array.isArray(list?.result?.tools) && list.result.tools.length === 6, "tools/list → 6 tools");
check(list?.result?.tools?.every((t) => t.name && t.inputSchema?.type === "object"), "each tool has name + object schema");
check(Array.isArray(call?.result?.content) && typeof call.result.content[0]?.text === "string", "tools/call → well-formed content");
check(bad?.result?.isError === true, "unknown tool → isError result (not a crash)");

console.error(failed ? `\n${failed} FAILED` : "\nall good");
process.exit(failed ? 1 : 0);
