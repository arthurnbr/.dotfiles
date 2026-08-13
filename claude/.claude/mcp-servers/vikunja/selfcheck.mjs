#!/usr/bin/env node
// Protocol self-check for the Vikunja MCP server. Verifies the JSON-RPC/MCP
// handshake, tool advertising, and (if the instance is reachable) a live read.
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
send({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "vikunja_info", arguments: {} } });
send({ jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "nope", arguments: {} } });

await new Promise((r) => setTimeout(r, 2500));
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

check(init?.result?.serverInfo?.name === "vikunja", "initialize → serverInfo.name=vikunja");
const names = (list?.result?.tools || []).map((t) => t.name);
check(names.length >= 50, `tools/list → ${names.length} tools (>=50)`);
check(names.includes("vikunja_request"), "generic vikunja_request present");
check(new Set(names).size === names.length, "no duplicate tool names");
check((list?.result?.tools || []).every((t) => t.inputSchema?.type === "object"), "every tool has object schema");
check(Array.isArray(call?.result?.content) && typeof call.result.content[0]?.text === "string", "tools/call vikunja_info → well-formed");
check(bad?.result?.isError === true, "unknown tool → isError");

console.error(failed ? `\n${failed} FAILED` : `\nall good (${names.length} tools)`);
process.exit(failed ? 1 : 0);
