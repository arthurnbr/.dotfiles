// The three dev servers of an Eduvia checkout: what eduvia.sh reports, matched with
// herdr-core's terminals, and the actions on them. A checkout is `where`:
// { machine: null (this computer) | a name from `hc machine ls`, root: its folder there }.
import { exec, hc, appHome, readTextFile, terminals, openOverlay, window } from "herdr";

export const SERVERS = [
  { id: "front", name: "Front" },
  { id: "back", name: "Back" },
  { id: "histoire", name: "Histoire" },
];

export const icon = (name) => `mods/eduvia-servers/${name}.svg`;
const LOCAL_SCRIPT = () => `${appHome()}/mods/eduvia-servers/eduvia.sh`;

// --- eduvia.sh on each machine ----------------------------------------------------

// Remote machines get a copy in ~/.cache/eduvia-servers/, named after its content: an
// edited script is copied again, and every window and version can share the folder.
let source = null;
const installed = new Map(); // machine → path, or a pending promise

async function scriptOn(machine) {
  if (!machine) return LOCAL_SCRIPT();
  const known = installed.get(machine);
  if (known) return known;
  const install = (async () => {
    source ??= await readTextFile(LOCAL_SCRIPT());
    if (source === null) throw new Error("eduvia.sh introuvable");
    let h = 0;
    for (let i = 0; i < source.length; i++) h = (Math.imul(h, 31) + source.charCodeAt(i)) | 0;
    const name = `eduvia-${(h >>> 0).toString(16)}.sh`;
    // The content goes as one argument: hc exec passes bytes as given (no shell, no stdin).
    const r = await exec("sh", ["-c",
      'd="$HOME/.cache/eduvia-servers"; f="$d/$1"; [ -x "$f" ] || { mkdir -p "$d" && printf %s "$2" > "$f.tmp" && chmod +x "$f.tmp" && mv "$f.tmp" "$f"; } && printf %s "$f"',
      "sh", name, source], { on: machine, timeout: 20000 });
    if (r.code !== 0 || !r.stdout) throw new Error(`copie de eduvia.sh sur ${machine} : ${(r.stderr || r.stdout).trim()}`);
    return r.stdout;
  })();
  installed.set(machine, install);
  try {
    const path = await install;
    installed.set(machine, path);
    return path;
  } catch (e) {
    installed.delete(machine);
    throw e;
  }
}

async function run(machine, args, timeout = 10000) {
  return exec(await scriptOn(machine), args, { on: machine, timeout });
}

// --- reading ----------------------------------------------------------------------

/** The Eduvia checkout holding the first of these folders that is in one, or null. */
export async function findRoot(machine, folders) {
  if (!folders.length) return null;
  const r = await run(machine, ["root", ...folders]);
  return r.code === 0 ? r.stdout.trim() || null : null;
}

export async function readStatus(where) {
  const r = await run(where.machine, ["status", where.root]);
  if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim() || `eduvia.sh status : code ${r.code}`);
  const st = { env: {}, expected: {}, listeners: [], pending: {}, errors: {}, files: {}, missing: [] };
  for (const line of r.stdout.split("\n")) {
    const f = line.split("\t");
    switch (f[0]) {
      case "V": st.env[f[1]] = f[2]; break;
      case "X": st.expected[f[1]] = Number(f[2]); break;
      case "L": st.listeners.push({
        pid: Number(f[1]), ports: f[2].split(",").map(Number), addrs: f[3].split(","),
        cwd: f[4], chain: f[5].split(",").map(Number), cmd: f[6] ?? "",
      }); break;
      case "P": st.pending[f[1]] = { action: f[2], since: Number(f[3]) * 1000 }; break;
      case "E": st.errors[f[1]] = f[2]; break;
      case "F": st.files[f[1]] = f[2]; break;
      case "M": st.missing.push(f[1]); break;
    }
  }
  return st;
}

function serverOf(l, root) {
  const inside = (dir) => l.cwd === `${root}/${dir}` || l.cwd.startsWith(`${root}/${dir}/`);
  if (inside("frontend") && /histoire/.test(l.cmd)) return "histoire";
  if (inside("frontend") && /nuxt/.test(l.cmd)) return "front";
  if (inside("backend") && /^puma |rails/.test(l.cmd)) return "back";
  return null;
}

// terminals() names another machine's terminals `machine/t7`; their labels and pids are
// that machine's. eduvia.sh runs there and wants the bare address.
const machineOf = (address) => (address.includes("/") ? address.slice(0, address.indexOf("/")) : null);
const bare = (address) => address.slice(address.indexOf("/") + 1);

/**
 * Each server's state:
 * - state: running | starting | pending (an action under way) | failed | stopped
 * - how: managed (its own terminal, started here), inplace (a shell's foreground program,
 *   restarted in that shell), external (anything else: an agent's, another app's), none
 * - term: the terminal showing its output (managed or inplace) as terminals() names it
 */
export function describe(st, where, optimistic = {}) {
  const { machine, root } = where;
  const live = terminals().filter((t) => t.state === "live" && machineOf(t.address) === (machine ?? null));
  return SERVERS.map((def) => {
    const expected = st.expected[def.id];
    const own = st.listeners.filter((l) => serverOf(l, root) === def.id);
    const listener = own.find((l) => l.ports.includes(expected)) ?? own[0] ?? null;
    const managed = live.find((t) => t.labels?.["eduvia.root"] === root && t.labels?.["eduvia.server"] === def.id) ?? null;
    let how = "none", term = null;
    if (listener) {
      const chain = new Set([listener.pid, ...listener.chain]);
      const host = live.find((t) => chain.has(t.pid));
      if (host && host.address === managed?.address) { how = "managed"; term = host; }
      // A person's shell running it in the foreground; never an agent's terminal.
      else if (host && !host.reported && !host.program?.agent && chain.has(host.foreground?.pid)) { how = "inplace"; term = host; }
      else how = "external";
    } else if (managed) { how = "managed"; term = managed; }
    const failed = managed?.labels?.["eduvia.failed"];
    const pending = st.pending[def.id] ?? optimistic[def.id] ?? null;
    const state = pending ? "pending" : listener ? "running" : failed ? "failed" : managed ? "starting" : "stopped";
    const port = listener ? (listener.ports.includes(expected) ? expected : listener.ports[0]) : expected;
    return {
      ...def, state, how, pending, port, listener,
      pid: listener?.pid ?? null,
      term: term?.address ?? null,
      error: st.errors[def.id] ?? (failed ? `S’est arrêté (code ${failed}) : voir les logs` : null),
      // Histoire must be reachable from other machines.
      exposed: listener ? listener.addrs.some((a) => a === "0.0.0.0" || a === "*" || a === "[::]") : null,
      file: st.files[def.id] ?? null,
    };
  });
}

// --- acting -----------------------------------------------------------------------

/** Where a browser here reaches it. Remote: the machine's ssh host, unless Histoire's. */
export function url(s, env, host) {
  if (s.id === "front") return `https://${env.EDUVIA_FRONT_HOST ?? "front.local.dev"}:${s.port}`;
  if (s.id === "back") return `https://${env.EDUVIA_BACK_HOST ?? "back.local.dev"}:${s.port}`;
  return `http://${host ?? "localhost"}:${s.port}`;
}

export function openUrl(link) {
  return exec(window()?.platform === "macos" ? "open" : "xdg-open", [link]).catch(() => null);
}

/** Starts, stops or restarts a server. The action runs in a terminal of its own on the
 *  checkout's machine (no pane, removed when done), so it outlives the popover; the
 *  popover follows it through the status (P records). */
export async function control(action, where, s) {
  const path = await scriptOn(where.machine);
  const args = ["run", "--bg", "--json", "--no-parent", "--no-notify", "--rm", "--cwd", where.root,
    ...(where.machine ? ["--on", where.machine] : []), "--label", "eduvia.ctl=1",
    "--", path, "ctl", action, where.root, s.id, s.how, s.term ? bare(s.term) : "-", String(s.pid ?? "-")];
  const r = await hc(args);
  if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim() || `hc run : code ${r.code}`);
}

/** Its own terminal when it has one, else its log file (Back, Front). */
export function logSource(s) {
  if (s.term) return { terminal: s.term };
  if (s.file) return { file: s.file };
  return null;
}

/** A window per server, several at once: the live terminal, or the log file followed. */
export async function openLogs(where, s, title) {
  const src = logSource(s);
  if (!src) return;
  let terminal = src.terminal, tail = null;
  if (!terminal) {
    const r = await hc(["run", "--bg", "--json", "--no-parent", "--no-notify", "--rm", "--cwd", where.root,
      ...(where.machine ? ["--on", where.machine] : []), "--label", "eduvia.tail=1",
      "--", "tail", "-n", "2000", "-F", src.file]);
    terminal = tail = JSON.parse(r.stdout).address;
  }
  const i = SERVERS.findIndex((d) => d.id === s.id);
  openOverlay({
    kind: "window", key: `eduvia-logs:${where.machine ?? ""}:${where.root}:${s.id}`, width: 820, height: 480,
    at: { x: 120 + i * 56, y: 96 + i * 48 },
    layout: { type: "column", children: [
      { type: "block", size: { px: 34 }, content: { mod: "eduvia-servers", props: {
        role: "logs", machine: where.machine, root: where.root, server: s.id, name: s.name, title, terminal, tail, file: tail ? src.file : null } } },
      { type: "block", content: { terminal } },
    ] },
  });
}

/** The env's colour (favicon, eduvia-env list): hsl(354° + 36° × slot, 79 %, 66 %). */
export function slotColor(slot) {
  const h = (354 + 36 * slot) % 360, s = 0.79, l = 0.66, a = s * Math.min(l, 1 - l);
  const f = (n) => {
    const k = (n + h / 30) % 12;
    return Math.round(255 * (l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1))));
  };
  return "#" + [f(0), f(8), f(4)].map((x) => x.toString(16).padStart(2, "0")).join("");
}
