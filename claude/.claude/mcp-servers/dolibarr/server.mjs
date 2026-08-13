#!/usr/bin/env node
// Dolibarr MCP server — zero-dependency stdio JSON-RPC (Model Context Protocol).
//
// WHAT: exposes NS. CAPITAL's Dolibarr ERP (erp.nobrega.fr) as MCP tools, usable
//       by any MCP client (OMP, Cursor, Claude Desktop, openclaw/hermes, ...).
// RUN:  node server.mjs   (also works with: bun server.mjs)
// WIRE (stdio server), same snippet for every client — see mcp.example.json:
//       { "command": "node", "args": ["<ABS>/server.mjs"] }
// SECRET: ~/.secrets/dolibarr.env  (DOLIBARR_URL, DOLAPIKEY), synced via Seafile.
//       The server loads it itself; no secret ever passes through client config.
// SAFETY: read + normal business writes only (devis, factures, PDF, FEC).
//       NO DELETE / /setup / module toggles / mass update — those stay manual (UI).
//
// Deps: none. Node >= 20 (global fetch, AbortController, import.meta.dirname).

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const NAME = "dolibarr";
const VERSION = "0.1.0";
const DEFAULT_BASE = "https://erp.nobrega.fr/api/index.php";
const TIMEOUT_MS = 30_000;

// ── secret + HTTP ──────────────────────────────────────────────────────────
let _cfg = null;
function config() {
  if (_cfg) return _cfg;
  const path = join(homedir(), ".secrets", "dolibarr.env");
  let raw;
  try {
    raw = readFileSync(path, "utf8");
  } catch {
    throw new Error(
      "~/.secrets/dolibarr.env introuvable. Synchronise la library des secrets " +
        "(Seafile) ou crée le fichier avec DOLIBARR_URL et DOLAPIKEY (cf. skill dolibarr).",
    );
  }
  const env = {};
  for (const line of raw.split("\n")) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
  if (!env.DOLAPIKEY) throw new Error("DOLAPIKEY absent de ~/.secrets/dolibarr.env");
  let base = (env.DOLIBARR_URL || DEFAULT_BASE).replace(/\/+$/, "");
  if (!base.includes("/api/index.php")) base += "/api/index.php";
  _cfg = { base, key: env.DOLAPIKEY };
  return _cfg;
}

async function api(method, path, body) {
  const { base, key } = config();
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  let res;
  try {
    res = await fetch(base + path, {
      method,
      headers: {
        DOLAPIKEY: key,
        Accept: "application/json",
        ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: ctrl.signal,
    });
  } catch (e) {
    if (e.name === "AbortError") throw new Error(`Timeout ${TIMEOUT_MS}ms sur ${method} ${path}`);
    throw new Error(`Réseau (${method} ${path}): ${e.message}`);
  } finally {
    clearTimeout(timer);
  }
  const text = await res.text();
  if (!res.ok) throw new Error(`Dolibarr ${res.status} ${method} ${path}: ${text.slice(0, 800)}`);
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

const result = (summary, data) => ({
  content: [
    {
      type: "text",
      text: data === undefined ? summary : `${summary}\n\n${JSON.stringify(data, null, 2)}`,
    },
  ],
});

const LINE_ITEM = {
  type: "object",
  properties: {
    desc: { type: "string" },
    subprice: { type: "number", description: "Prix unitaire HT" },
    qty: { type: "number" },
    tva_tx: { type: "number", description: "Taux TVA en %, défaut 20" },
  },
  required: ["desc", "subprice", "qty"],
};

// ── tools ──────────────────────────────────────────────────────────────────
const TOOLS = [
  {
    name: "dolibarr_get",
    description:
      "GET lecture seule sur n'importe quel endpoint de l'API Dolibarr (échappatoire " +
      "universelle pour les lectures). Ex: /status, /thirdparties?limit=5, " +
      "/thirdparties/email/x@y.fr, /invoices/ref/FA2026-0001, /proposals/42. " +
      "Filtres: ?sqlfilters=(t.datec:>=:'2026-01-01') ?limit= ?page= ?properties=",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Chemin API commençant par / (query string incluse)." },
      },
      required: ["path"],
    },
    async run({ path }) {
      if (typeof path !== "string" || !path) throw new Error("path requis");
      if (!path.startsWith("/")) path = "/" + path;
      return result(`GET ${path}`, await api("GET", path));
    },
  },
  {
    name: "dolibarr_thirdparty_create",
    description: "Crée un tiers (client/fournisseur). Renvoie le socid.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string" },
        client: { type: "integer", enum: [0, 1, 2, 3], description: "0=non 1=client 2=prospect 3=client+prospect" },
        fournisseur: { type: "integer", enum: [0, 1] },
        email: { type: "string" },
        phone: { type: "string" },
        address: { type: "string" },
        zip: { type: "string" },
        town: { type: "string" },
        country_code: { type: "string", description: "Ex: FR" },
        tva_intra: { type: "string" },
        idprof1: { type: "string", description: "SIREN (FR)" },
        idprof2: { type: "string", description: "SIRET (FR)" },
      },
      required: ["name"],
    },
    async run(args) {
      const socid = await api("POST", "/thirdparties", { client: 1, ...args });
      return result(`Tiers créé — socid=${socid}`, { socid });
    },
  },
  {
    name: "dolibarr_proposal_create",
    description:
      "Crée un devis (proposition) brouillon avec ses lignes ; le valide (numérote) si validate=true. Renvoie l'id.",
    inputSchema: {
      type: "object",
      properties: {
        socid: { type: "integer" },
        lines: { type: "array", items: LINE_ITEM, minItems: 1 },
        date: { type: "integer", description: "Timestamp unix, défaut: maintenant" },
        note_public: { type: "string" },
        validate: { type: "boolean", description: "Valider après création" },
      },
      required: ["socid", "lines"],
    },
    async run({ socid, lines, date, note_public, validate }) {
      const id = await api("POST", "/proposals", {
        socid,
        date: date ?? Math.floor(Date.now() / 1000),
        ...(note_public ? { note_public } : {}),
      });
      for (const l of lines) {
        await api("POST", `/proposals/${id}/lines`, {
          desc: l.desc,
          subprice: l.subprice,
          qty: l.qty,
          tva_tx: l.tva_tx ?? 20,
        });
      }
      let msg = `Devis créé — id=${id}, ${lines.length} ligne(s)`;
      if (validate) {
        await api("POST", `/proposals/${id}/validate`, {});
        msg += " — validé";
      }
      return result(msg, { id });
    },
  },
  {
    name: "dolibarr_invoice_create",
    description:
      "Crée une facture client brouillon avec ses lignes ; la valide (numérote) si validate=true. Renvoie l'id.",
    inputSchema: {
      type: "object",
      properties: {
        socid: { type: "integer" },
        lines: { type: "array", items: LINE_ITEM, minItems: 1 },
        date: { type: "integer", description: "Timestamp unix, défaut: maintenant" },
        note_public: { type: "string" },
        validate: { type: "boolean" },
      },
      required: ["socid", "lines"],
    },
    async run({ socid, lines, date, note_public, validate }) {
      const id = await api("POST", "/invoices", {
        socid,
        type: 0,
        date: date ?? Math.floor(Date.now() / 1000),
        lines: lines.map((l) => ({ desc: l.desc, subprice: l.subprice, qty: l.qty, tva_tx: l.tva_tx ?? 20 })),
        ...(note_public ? { note_public } : {}),
      });
      let msg = `Facture créée — id=${id}, ${lines.length} ligne(s)`;
      if (validate) {
        await api("POST", `/invoices/${id}/validate`, {});
        msg += " — validée + numérotée";
      }
      return result(msg, { id });
    },
  },
  {
    name: "dolibarr_invoice_builddoc",
    description:
      "Génère le PDF (et le Factur-X si le module einvoicing est actif) d'une facture. " +
      "Fournis ref (ex: FA2026-0001) ou id. doctemplate = modèle PDF (défaut: crabe).",
    inputSchema: {
      type: "object",
      properties: {
        ref: { type: "string", description: "Référence facture (ex: FA2026-0001)" },
        id: { type: "integer", description: "Id facture (alternative à ref)" },
        doctemplate: { type: "string", description: "Modèle PDF, défaut: crabe" },
        langcode: { type: "string", description: "Défaut: fr_FR" },
      },
    },
    async run({ ref, id, doctemplate, langcode }) {
      if (!ref) {
        if (!id) throw new Error("Fournis ref ou id.");
        const inv = await api("GET", `/invoices/${id}`);
        ref = inv?.ref;
        if (!ref) throw new Error(`Facture ${id} sans ref (brouillon non validé ?).`);
      }
      const out = await api("PUT", "/documents/builddoc", {
        modulepart: "facture",
        original_file: `${ref}/${ref}.pdf`,
        doctemplate: doctemplate || "crabe",
        langcode: langcode || "fr_FR",
      });
      return result(`PDF généré pour ${ref}`, out);
    },
  },
  {
    name: "dolibarr_fec_export",
    description:
      "Export comptable pour l'expert-comptable (FEC). format: 1000=FEC, 1010=FEC2, 1=CSV. " +
      "period ∈ lastmonth,currentmonth,last3months,last6months,currentyear,lastyear,fiscalyear,lastfiscalyear,custom.",
    inputSchema: {
      type: "object",
      properties: {
        period: { type: "string", description: "Défaut: fiscalyear" },
        format: { type: "integer", description: "Défaut: 1000 (FEC)" },
        date_min: { type: "string", description: "YYYY-MM-DD si period=custom" },
        date_max: { type: "string", description: "YYYY-MM-DD si period=custom" },
      },
    },
    async run({ period, format, date_min, date_max }) {
      const q = new URLSearchParams({
        period: period || "fiscalyear",
        format: String(format ?? 1000),
        ...(date_min ? { date_min } : {}),
        ...(date_max ? { date_max } : {}),
      });
      return result(
        `Export comptable (${period || "fiscalyear"}, format ${format ?? 1000})`,
        await api("GET", `/accountancy/exportdata?${q}`),
      );
    },
  },
];

// ── MCP stdio protocol (newline-delimited JSON-RPC 2.0) ─────────────────────
const byName = new Map(TOOLS.map((t) => [t.name, t]));
const send = (msg) => process.stdout.write(JSON.stringify(msg) + "\n");
const reply = (id, res) => send({ jsonrpc: "2.0", id, result: res });
const fail = (id, code, message) => send({ jsonrpc: "2.0", id, error: { code, message } });

async function handle(msg) {
  const { id, method, params } = msg;
  const isRequest = id !== undefined && id !== null;
  switch (method) {
    case "initialize":
      return reply(id, {
        protocolVersion: params?.protocolVersion || "2024-11-05",
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: NAME, version: VERSION },
      });
    case "tools/list":
      return reply(id, {
        tools: TOOLS.map((t) => ({ name: t.name, description: t.description, inputSchema: t.inputSchema })),
      });
    case "tools/call": {
      const tool = byName.get(params?.name);
      if (!tool)
        return reply(id, { content: [{ type: "text", text: `Outil inconnu: ${params?.name}` }], isError: true });
      try {
        return reply(id, await tool.run(params?.arguments || {}));
      } catch (e) {
        return reply(id, { content: [{ type: "text", text: `Erreur: ${e.message}` }], isError: true });
      }
    }
    case "ping":
      return isRequest ? reply(id, {}) : undefined;
    default:
      // notifications (initialized, cancelled, ...) have no id → no reply
      if (isRequest) return fail(id, -32601, `Méthode inconnue: ${method}`);
  }
}

let buf = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buf += chunk;
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, i).trim();
    buf = buf.slice(i + 1);
    if (!line) continue;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      fail(null, -32700, "Parse error");
      continue;
    }
    handle(msg).catch((e) => {
      if (msg?.id != null) fail(msg.id, -32603, e?.message || "Internal error");
    });
  }
});
process.stdin.on("end", () => process.exit(0));
