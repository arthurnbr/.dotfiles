#!/usr/bin/env node
// Vikunja MCP server — zero-dependency stdio JSON-RPC (Model Context Protocol).
//
// WHAT: exposes a Vikunja instance (todo.nobrega.fr, v2.5.0) as MCP tools, usable
//       by any MCP client (OMP, Cursor, Claude Desktop, openclaw/hermes, ...).
// RUN:  node server.mjs   (also works with: bun server.mjs)
// WIRE (stdio), ABSOLUTE path — clients do not reliably expand ${HOME}:
//       { "command": "node", "args": ["/home/arthur/.claude/mcp-servers/vikunja/server.mjs"] }
// SECRET: ~/.secrets/vikunja.env  (VIKUNJA_URL, VIKUNJA_TOKEN), synced via Seafile.
//       The server loads it itself; no token passes through client config.
// COVERAGE: `vikunja_request` reaches ANY endpoint (100% of the API, incl. admin/
//       migrations/future). Typed tools below cover every core resource ergonomically.
//
// Deps: none. Node >= 20 (global fetch, FormData, Blob, AbortController).

import { readFileSync, appendFileSync } from "node:fs";
import { basename } from "node:path";
import { homedir } from "node:os";
import { join } from "node:path";

const NAME = "vikunja";
const VERSION = "0.1.0";
const DEFAULT_URL = "https://todo.nobrega.fr";
const TIMEOUT_MS = 30_000;

// ── secret + HTTP ──────────────────────────────────────────────────────────
let _cfg = null;
function config() {
  if (_cfg) return _cfg;
  const path = join(homedir(), ".secrets", "vikunja.env");
  let raw;
  try {
    raw = readFileSync(path, "utf8");
  } catch {
    throw new Error(
      "~/.secrets/vikunja.env introuvable. Synchronise la library des secrets (Seafile) " +
        "ou crée le fichier avec VIKUNJA_URL et VIKUNJA_TOKEN.",
    );
  }
  const env = {};
  for (const line of raw.split("\n")) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
  if (!env.VIKUNJA_TOKEN) throw new Error("VIKUNJA_TOKEN absent de ~/.secrets/vikunja.env");
  const base = (env.VIKUNJA_URL || DEFAULT_URL).replace(/\/+$/, "") + "/api/v1";
  _cfg = { base, token: env.VIKUNJA_TOKEN };
  return _cfg;
}

function qstr(query) {
  if (!query) return "";
  const sp = new URLSearchParams();
  for (const [k, v] of Object.entries(query)) {
    if (v === undefined || v === null || v === "") continue;
    if (Array.isArray(v)) for (const item of v) sp.append(k, String(item));
    else sp.append(k, String(v));
  }
  const s = sp.toString();
  return s ? `?${s}` : "";
}

async function api(method, path, { body, query, formData } = {}) {
  const { base, token } = config();
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  const headers = { Authorization: `Bearer ${token}`, Accept: "application/json" };
  let payload;
  if (formData) {
    payload = formData; // fetch sets multipart boundary
  } else if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }
  let res;
  try {
    res = await fetch(base + path + qstr(query), { method, headers, body: payload, signal: ctrl.signal });
  } catch (e) {
    if (e.name === "AbortError") throw new Error(`Timeout ${TIMEOUT_MS}ms sur ${method} ${path}`);
    throw new Error(`Réseau (${method} ${path}): ${e.message}`);
  } finally {
    clearTimeout(timer);
  }
  const text = await res.text();
  if (!res.ok) throw new Error(`Vikunja ${res.status} ${method} ${path}: ${text.slice(0, 800)}`);
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

// schema shorthands
const INT = (d) => ({ type: "integer", ...(d ? { description: d } : {}) });
const STR = (d) => ({ type: "string", ...(d ? { description: d } : {}) });
const BOOL = (d) => ({ type: "boolean", ...(d ? { description: d } : {}) });
const NUM = (d) => ({ type: "number", ...(d ? { description: d } : {}) });
const OBJ = (properties, required = []) => ({ type: "object", properties, required });

// Writable task fields (RFC3339 for dates; empty string clears a date).
const TASK_FIELDS = {
  title: STR(),
  description: STR("HTML or plain text"),
  done: BOOL(),
  due_date: STR("RFC3339 e.g. 2026-08-20T09:00:00Z; '' clears"),
  start_date: STR("RFC3339"),
  end_date: STR("RFC3339"),
  priority: INT("0 unset,1 low,2 medium,3 high,4 urgent,5 DO NOW"),
  percent_done: NUM("0..1"),
  hex_color: STR("hex without #"),
  is_favorite: BOOL(),
  bucket_id: INT("kanban bucket id"),
  position: NUM("ordering position"),
  repeat_after: INT("seconds between repeats (0=none)"),
  repeat_mode: INT("0 default,1 monthly,2 from current date"),
};

const TOOLS = [];
const tool = (name, description, inputSchema, run) => TOOLS.push({ name, description, inputSchema, run });

// ── meta / generic ─────────────────────────────────────────────────────────
tool(
  "vikunja_request",
  "Échappatoire universelle : appelle N'IMPORTE QUEL endpoint de l'API Vikunja (couvre 100% des features, y compris admin/migrations). method ∈ GET/PUT/POST/DELETE. path commence par / (relatif à /api/v1). Ex: PUT /projects {\"title\":\"x\"}. query = objet de paramètres.",
  OBJ(
    {
      method: { type: "string", enum: ["GET", "PUT", "POST", "DELETE"] },
      path: STR("chemin après /api/v1, commençant par /"),
      body: { type: "object", description: "corps JSON (PUT/POST)" },
      query: { type: "object", description: "paramètres de query" },
    },
    ["method", "path"],
  ),
  async ({ method, path, body, query }) => {
    if (!path.startsWith("/")) path = "/" + path;
    return result(`${method} ${path}`, await api(method, path, { body, query }));
  },
);
tool("vikunja_info", "Infos publiques de l'instance (version, features).", OBJ({}), async () =>
  result("GET /info", await api("GET", "/info")),
);
tool("vikunja_whoami", "Utilisateur courant (celui du token).", OBJ({}), async () =>
  result("GET /user", await api("GET", "/user")),
);
tool(
  "vikunja_users_search",
  "Cherche des utilisateurs (pour assignation/partage).",
  OBJ({ s: STR("terme de recherche (username)") }, ["s"]),
  async ({ s }) => result(`users?s=${s}`, await api("GET", "/users", { query: { s } })),
);

// ── projects ───────────────────────────────────────────────────────────────
tool(
  "vikunja_projects_list",
  "Liste les projets (arborescence via parent_project_id). Les filtres sauvegardés apparaissent en id négatif.",
  OBJ({ page: INT(), per_page: INT(), s: STR("recherche par titre"), is_archived: BOOL() }),
  async (q) => result("GET /projects", await api("GET", "/projects", { query: q })),
);
tool("vikunja_project_get", "Détail d'un projet.", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`GET /projects/${id}`, await api("GET", `/projects/${id}`)),
);
tool(
  "vikunja_project_create",
  "Crée un projet (sous-projet si parent_project_id).",
  OBJ(
    {
      title: STR(),
      description: STR(),
      parent_project_id: INT(),
      hex_color: STR("hex sans #"),
      is_favorite: BOOL(),
      identifier: STR("préfixe court des tâches, ex ABC"),
    },
    ["title"],
  ),
  async (b) => result("Projet créé", await api("PUT", "/projects", { body: b })),
);
tool(
  "vikunja_project_update",
  "Met à jour un projet (titre, description, couleur, archivage, favori, parent...).",
  OBJ(
    {
      id: INT(),
      title: STR(),
      description: STR(),
      parent_project_id: INT(),
      hex_color: STR(),
      is_favorite: BOOL(),
      is_archived: BOOL(),
      identifier: STR(),
    },
    ["id"],
  ),
  async ({ id, ...b }) => result(`Projet ${id} mis à jour`, await api("POST", `/projects/${id}`, { body: b })),
);
tool("vikunja_project_delete", "Supprime un projet (et ses tâches).", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`Projet ${id} supprimé`, await api("DELETE", `/projects/${id}`)),
);
tool(
  "vikunja_project_duplicate",
  "Duplique un projet.",
  OBJ({ id: INT(), parent_project_id: INT("projet parent de la copie") }, ["id"]),
  async ({ id, parent_project_id }) =>
    result(`Projet ${id} dupliqué`, await api("PUT", `/projects/${id}/duplicate`, { body: { parent_project_id } })),
);

// ── tasks ──────────────────────────────────────────────────────────────────
tool(
  "vikunja_tasks_list",
  "Liste/filtre les tâches de TOUS les projets. filter = requête Vikunja, ex: 'done = false && priority >= 3', 'due_date < now', 'labels in 1,2', 'assignees in bot'. Opérateurs: = != > >= < <= like in, combinés par && ||. sort_by/order_by acceptent plusieurs valeurs. expand='subtasks' pour inclure les sous-tâches.",
  OBJ({
    filter: STR("requête de filtre Vikunja"),
    s: STR("recherche plein-texte"),
    sort_by: { type: "array", items: { type: "string" }, description: "ex ['due_date','priority']" },
    order_by: { type: "array", items: { type: "string" }, description: "asc|desc par champ trié" },
    page: INT(),
    per_page: INT(),
    filter_timezone: STR("ex Europe/Paris"),
    expand: STR("subtasks"),
  }),
  async (q) => result("GET /tasks", await api("GET", "/tasks", { query: q })),
);
tool(
  "vikunja_project_tasks",
  "Liste les tâches d'un projet (via une vue). Si view_id omis, la vue 'list' est utilisée.",
  OBJ({ project_id: INT(), view_id: INT("id de vue; défaut = vue list"), filter: STR(), s: STR(), page: INT(), per_page: INT() }, ["project_id"]),
  async ({ project_id, view_id, ...q }) => {
    if (!view_id) {
      const views = await api("GET", `/projects/${project_id}/views`);
      view_id = (Array.isArray(views) ? views.find((v) => v.view_kind === "list") : null)?.id;
      if (!view_id) throw new Error("Pas de vue 'list' trouvée; passe view_id.");
    }
    return result(`tasks projet ${project_id} (vue ${view_id})`, await api("GET", `/projects/${project_id}/views/${view_id}/tasks`, { query: q }));
  },
);
tool("vikunja_task_get", "Détail d'une tâche.", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`GET /tasks/${id}`, await api("GET", `/tasks/${id}`)),
);
tool(
  "vikunja_task_create",
  "Crée une tâche dans un projet.",
  OBJ({ project_id: INT("projet cible"), ...TASK_FIELDS }, ["project_id", "title"]),
  async ({ project_id, ...b }) => result("Tâche créée", await api("PUT", `/projects/${project_id}/tasks`, { body: b })),
);
tool(
  "vikunja_task_update",
  "Met à jour une tâche (done, dates, priorité, %, couleur, favori, bucket, répétition, déplacement via project_id...). Ne passe que les champs à changer.",
  OBJ({ id: INT(), ...TASK_FIELDS, project_id: INT("déplacer vers ce projet") }, ["id"]),
  async ({ id, ...b }) => result(`Tâche ${id} mise à jour`, await api("POST", `/tasks/${id}`, { body: b })),
);
tool("vikunja_task_delete", "Supprime une tâche.", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`Tâche ${id} supprimée`, await api("DELETE", `/tasks/${id}`)),
);
tool("vikunja_task_duplicate", "Duplique une tâche.", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`Tâche ${id} dupliquée`, await api("PUT", `/tasks/${id}/duplicate`)),
);
tool(
  "vikunja_tasks_bulk_update",
  "Met à jour plusieurs tâches d'un coup (mêmes champs appliqués à tous les task_ids).",
  OBJ({ task_ids: { type: "array", items: INT() }, ...TASK_FIELDS }, ["task_ids"]),
  async ({ task_ids, ...b }) => result(`Bulk update ${task_ids.length} tâches`, await api("POST", "/tasks/bulk", { body: { task_ids, ...b } })),
);
tool(
  "vikunja_task_set_position",
  "Positionne une tâche (ordre) dans une vue.",
  OBJ({ id: INT(), position: NUM(), project_view_id: INT() }, ["id", "position"]),
  async ({ id, ...b }) => result(`Position tâche ${id}`, await api("POST", `/tasks/${id}/position`, { body: b })),
);

// ── task labels ─────────────────────────────────────────────────────────────
tool("vikunja_task_labels", "Labels d'une tâche.", OBJ({ task_id: INT() }, ["task_id"]), async ({ task_id }) =>
  result(`labels tâche ${task_id}`, await api("GET", `/tasks/${task_id}/labels`)),
);
tool(
  "vikunja_task_add_label",
  "Ajoute un label à une tâche.",
  OBJ({ task_id: INT(), label_id: INT() }, ["task_id", "label_id"]),
  async ({ task_id, label_id }) => result("Label ajouté", await api("PUT", `/tasks/${task_id}/labels`, { body: { label_id } })),
);
tool(
  "vikunja_task_remove_label",
  "Retire un label d'une tâche.",
  OBJ({ task_id: INT(), label_id: INT() }, ["task_id", "label_id"]),
  async ({ task_id, label_id }) => result("Label retiré", await api("DELETE", `/tasks/${task_id}/labels/${label_id}`)),
);
tool(
  "vikunja_task_set_labels_bulk",
  "Remplace TOUS les labels d'une tâche par la liste fournie.",
  OBJ({ task_id: INT(), labels: { type: "array", items: OBJ({ id: INT() }) } }, ["task_id", "labels"]),
  async ({ task_id, labels }) => result("Labels remplacés", await api("POST", `/tasks/${task_id}/labels/bulk`, { body: { labels } })),
);

// ── labels ──────────────────────────────────────────────────────────────────
tool("vikunja_labels_list", "Liste les labels.", OBJ({ page: INT(), per_page: INT(), s: STR() }), async (q) =>
  result("GET /labels", await api("GET", "/labels", { query: q })),
);
tool(
  "vikunja_label_create",
  "Crée un label.",
  OBJ({ title: STR(), description: STR(), hex_color: STR("hex sans #") }, ["title"]),
  async (b) => result("Label créé", await api("PUT", "/labels", { body: b })),
);
tool(
  "vikunja_label_update",
  "Met à jour un label.",
  OBJ({ id: INT(), title: STR(), description: STR(), hex_color: STR() }, ["id"]),
  async ({ id, ...b }) => result(`Label ${id} mis à jour`, await api("POST", `/labels/${id}`, { body: b })),
);
tool("vikunja_label_delete", "Supprime un label.", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`Label ${id} supprimé`, await api("DELETE", `/labels/${id}`)),
);

// ── assignees ───────────────────────────────────────────────────────────────
tool("vikunja_task_assignees", "Assignés d'une tâche.", OBJ({ task_id: INT() }, ["task_id"]), async ({ task_id }) =>
  result(`assignees tâche ${task_id}`, await api("GET", `/tasks/${task_id}/assignees`)),
);
tool(
  "vikunja_task_assign",
  "Assigne un utilisateur à une tâche (user_id via vikunja_users_search).",
  OBJ({ task_id: INT(), user_id: INT() }, ["task_id", "user_id"]),
  async ({ task_id, user_id }) => result("Assigné", await api("PUT", `/tasks/${task_id}/assignees`, { body: { user_id } })),
);
tool(
  "vikunja_task_unassign",
  "Retire un assigné.",
  OBJ({ task_id: INT(), user_id: INT() }, ["task_id", "user_id"]),
  async ({ task_id, user_id }) => result("Désassigné", await api("DELETE", `/tasks/${task_id}/assignees/${user_id}`)),
);
tool(
  "vikunja_task_assign_bulk",
  "Remplace les assignés d'une tâche.",
  OBJ({ task_id: INT(), user_ids: { type: "array", items: INT() } }, ["task_id", "user_ids"]),
  async ({ task_id, user_ids }) => result("Assignés remplacés", await api("POST", `/tasks/${task_id}/assignees/bulk`, { body: { assignees: user_ids.map((user_id) => ({ user_id })) } })),
);

// ── comments ────────────────────────────────────────────────────────────────
tool("vikunja_task_comments", "Commentaires d'une tâche.", OBJ({ task_id: INT() }, ["task_id"]), async ({ task_id }) =>
  result(`comments tâche ${task_id}`, await api("GET", `/tasks/${task_id}/comments`)),
);
tool(
  "vikunja_task_comment_add",
  "Ajoute un commentaire.",
  OBJ({ task_id: INT(), comment: STR("texte (HTML autorisé)") }, ["task_id", "comment"]),
  async ({ task_id, comment }) => result("Commentaire ajouté", await api("PUT", `/tasks/${task_id}/comments`, { body: { comment } })),
);
tool(
  "vikunja_task_comment_update",
  "Modifie un commentaire.",
  OBJ({ task_id: INT(), comment_id: INT(), comment: STR() }, ["task_id", "comment_id", "comment"]),
  async ({ task_id, comment_id, comment }) => result("Commentaire modifié", await api("POST", `/tasks/${task_id}/comments/${comment_id}`, { body: { comment } })),
);
tool(
  "vikunja_task_comment_delete",
  "Supprime un commentaire.",
  OBJ({ task_id: INT(), comment_id: INT() }, ["task_id", "comment_id"]),
  async ({ task_id, comment_id }) => result("Commentaire supprimé", await api("DELETE", `/tasks/${task_id}/comments/${comment_id}`)),
);

// ── relations ───────────────────────────────────────────────────────────────
tool(
  "vikunja_task_relation_add",
  "Lie deux tâches. relation_kind ∈ subtask, parenttask, related, duplicateof, duplicates, blocking, blocked, precedes, follows, copiedfrom, copiedto.",
  OBJ({ task_id: INT(), other_task_id: INT(), relation_kind: STR() }, ["task_id", "other_task_id", "relation_kind"]),
  async ({ task_id, other_task_id, relation_kind }) =>
    result("Relation créée", await api("PUT", `/tasks/${task_id}/relations`, { body: { other_task_id, relation_kind, task_id } })),
);
tool(
  "vikunja_task_relation_delete",
  "Supprime une relation entre deux tâches.",
  OBJ({ task_id: INT(), relation_kind: STR(), other_task_id: INT() }, ["task_id", "relation_kind", "other_task_id"]),
  async ({ task_id, relation_kind, other_task_id }) =>
    result("Relation supprimée", await api("DELETE", `/tasks/${task_id}/relations/${relation_kind}/${other_task_id}`)),
);

// ── attachments ─────────────────────────────────────────────────────────────
tool("vikunja_task_attachments", "Liste les pièces jointes d'une tâche.", OBJ({ task_id: INT() }, ["task_id"]), async ({ task_id }) =>
  result(`attachments tâche ${task_id}`, await api("GET", `/tasks/${task_id}/attachments`)),
);
tool(
  "vikunja_task_attachment_upload",
  "Attache un fichier local à une tâche.",
  OBJ({ task_id: INT(), file_path: STR("chemin absolu du fichier") }, ["task_id", "file_path"]),
  async ({ task_id, file_path }) => {
    const buf = readFileSync(file_path);
    const fd = new FormData();
    fd.append("files", new Blob([buf]), basename(file_path));
    return result(`Fichier attaché à ${task_id}`, await api("PUT", `/tasks/${task_id}/attachments`, { formData: fd }));
  },
);
tool(
  "vikunja_task_attachment_delete",
  "Supprime une pièce jointe.",
  OBJ({ task_id: INT(), attachment_id: INT() }, ["task_id", "attachment_id"]),
  async ({ task_id, attachment_id }) => result("Pièce jointe supprimée", await api("DELETE", `/tasks/${task_id}/attachments/${attachment_id}`)),
);

// ── views & kanban buckets ───────────────────────────────────────────────────
tool("vikunja_project_views", "Vues d'un projet (list/gantt/table/kanban).", OBJ({ project_id: INT() }, ["project_id"]), async ({ project_id }) =>
  result(`vues projet ${project_id}`, await api("GET", `/projects/${project_id}/views`)),
);
tool(
  "vikunja_view_create",
  "Crée une vue de projet. view_kind ∈ list, gantt, table, kanban.",
  OBJ({ project_id: INT(), title: STR(), view_kind: STR() }, ["project_id", "title", "view_kind"]),
  async ({ project_id, ...b }) => result("Vue créée", await api("PUT", `/projects/${project_id}/views`, { body: b })),
);
tool(
  "vikunja_view_update",
  "Met à jour une vue (titre, filtre, buckets par défaut...).",
  OBJ({ project_id: INT(), view_id: INT(), title: STR(), view_kind: STR(), default_bucket_id: INT(), done_bucket_id: INT() }, ["project_id", "view_id"]),
  async ({ project_id, view_id, ...b }) => result("Vue mise à jour", await api("POST", `/projects/${project_id}/views/${view_id}`, { body: b })),
);
tool("vikunja_view_delete", "Supprime une vue.", OBJ({ project_id: INT(), view_id: INT() }, ["project_id", "view_id"]), async ({ project_id, view_id }) =>
  result("Vue supprimée", await api("DELETE", `/projects/${project_id}/views/${view_id}`)),
);
tool(
  "vikunja_buckets_list",
  "Buckets kanban d'une vue.",
  OBJ({ project_id: INT(), view_id: INT() }, ["project_id", "view_id"]),
  async ({ project_id, view_id }) => result("buckets", await api("GET", `/projects/${project_id}/views/${view_id}/buckets`)),
);
tool(
  "vikunja_bucket_create",
  "Crée un bucket kanban. limit=0 => illimité.",
  OBJ({ project_id: INT(), view_id: INT(), title: STR(), limit: INT() }, ["project_id", "view_id", "title"]),
  async ({ project_id, view_id, ...b }) => result("Bucket créé", await api("PUT", `/projects/${project_id}/views/${view_id}/buckets`, { body: b })),
);
tool(
  "vikunja_bucket_update",
  "Met à jour un bucket.",
  OBJ({ project_id: INT(), view_id: INT(), bucket_id: INT(), title: STR(), limit: INT() }, ["project_id", "view_id", "bucket_id"]),
  async ({ project_id, view_id, bucket_id, ...b }) => result("Bucket mis à jour", await api("POST", `/projects/${project_id}/views/${view_id}/buckets/${bucket_id}`, { body: b })),
);
tool(
  "vikunja_bucket_delete",
  "Supprime un bucket.",
  OBJ({ project_id: INT(), view_id: INT(), bucket_id: INT() }, ["project_id", "view_id", "bucket_id"]),
  async ({ project_id, view_id, bucket_id }) => result("Bucket supprimé", await api("DELETE", `/projects/${project_id}/views/${view_id}/buckets/${bucket_id}`)),
);
tool(
  "vikunja_task_set_bucket",
  "Déplace une tâche dans un bucket kanban.",
  OBJ({ project_id: INT(), view_id: INT(), bucket_id: INT(), task_id: INT() }, ["project_id", "view_id", "bucket_id", "task_id"]),
  async ({ project_id, view_id, bucket_id, task_id }) =>
    result("Tâche déplacée", await api("POST", `/projects/${project_id}/views/${view_id}/buckets/${bucket_id}/tasks`, { body: { task_id } })),
);

// ── saved filters ─────────────────────────────────────────────────────────────
tool(
  "vikunja_filter_create",
  "Crée un filtre sauvegardé (apparaît comme pseudo-projet à id négatif). filters = { filter: 'done = false', ... }.",
  OBJ({ title: STR(), description: STR(), filters: { type: "object" }, is_favorite: BOOL() }, ["title", "filters"]),
  async (b) => result("Filtre créé", await api("PUT", "/filters", { body: b })),
);
tool("vikunja_filter_get", "Détail d'un filtre sauvegardé.", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`GET /filters/${id}`, await api("GET", `/filters/${id}`)),
);
tool(
  "vikunja_filter_update",
  "Met à jour un filtre sauvegardé.",
  OBJ({ id: INT(), title: STR(), description: STR(), filters: { type: "object" }, is_favorite: BOOL() }, ["id"]),
  async ({ id, ...b }) => result(`Filtre ${id} mis à jour`, await api("POST", `/filters/${id}`, { body: b })),
);
tool("vikunja_filter_delete", "Supprime un filtre sauvegardé.", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`Filtre ${id} supprimé`, await api("DELETE", `/filters/${id}`)),
);

// ── teams ─────────────────────────────────────────────────────────────────────
tool("vikunja_teams_list", "Liste les équipes.", OBJ({ page: INT(), per_page: INT(), s: STR() }), async (q) =>
  result("GET /teams", await api("GET", "/teams", { query: q })),
);
tool("vikunja_team_get", "Détail d'une équipe.", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`GET /teams/${id}`, await api("GET", `/teams/${id}`)),
);
tool(
  "vikunja_team_create",
  "Crée une équipe.",
  OBJ({ name: STR(), description: STR(), is_public: BOOL() }, ["name"]),
  async (b) => result("Équipe créée", await api("PUT", "/teams", { body: b })),
);
tool(
  "vikunja_team_update",
  "Met à jour une équipe.",
  OBJ({ id: INT(), name: STR(), description: STR(), is_public: BOOL() }, ["id"]),
  async ({ id, ...b }) => result(`Équipe ${id} mise à jour`, await api("POST", `/teams/${id}`, { body: b })),
);
tool("vikunja_team_delete", "Supprime une équipe.", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`Équipe ${id} supprimée`, await api("DELETE", `/teams/${id}`)),
);
tool(
  "vikunja_team_add_member",
  "Ajoute un membre à une équipe.",
  OBJ({ team_id: INT(), user_id: INT() }, ["team_id", "user_id"]),
  async ({ team_id, user_id }) => result("Membre ajouté", await api("PUT", `/teams/${team_id}/members`, { body: { user_id } })),
);
tool(
  "vikunja_team_remove_member",
  "Retire un membre (par username).",
  OBJ({ team_id: INT(), username: STR() }, ["team_id", "username"]),
  async ({ team_id, username }) => result("Membre retiré", await api("DELETE", `/teams/${team_id}/members/${username}`)),
);

// ── project sharing (users / teams / link) ────────────────────────────────────
tool("vikunja_project_users", "Utilisateurs ayant accès à un projet.", OBJ({ project_id: INT() }, ["project_id"]), async ({ project_id }) =>
  result("project users", await api("GET", `/projects/${project_id}/users`)),
);
tool(
  "vikunja_project_add_user",
  "Partage un projet à un utilisateur. permission: 0 lecture,1 écriture,2 admin.",
  OBJ({ project_id: INT(), user_id: INT(), permission: INT() }, ["project_id", "user_id"]),
  async ({ project_id, user_id, permission }) => result("Utilisateur ajouté", await api("PUT", `/projects/${project_id}/users`, { body: { user_id, permission } })),
);
tool(
  "vikunja_project_remove_user",
  "Retire l'accès d'un utilisateur à un projet.",
  OBJ({ project_id: INT(), user_id: INT() }, ["project_id", "user_id"]),
  async ({ project_id, user_id }) => result("Utilisateur retiré", await api("DELETE", `/projects/${project_id}/users/${user_id}`)),
);
tool("vikunja_project_teams", "Équipes ayant accès à un projet.", OBJ({ project_id: INT() }, ["project_id"]), async ({ project_id }) =>
  result("project teams", await api("GET", `/projects/${project_id}/teams`)),
);
tool(
  "vikunja_project_add_team",
  "Partage un projet à une équipe. permission: 0 lecture,1 écriture,2 admin.",
  OBJ({ project_id: INT(), team_id: INT(), permission: INT() }, ["project_id", "team_id"]),
  async ({ project_id, team_id, permission }) => result("Équipe ajoutée", await api("PUT", `/projects/${project_id}/teams`, { body: { team_id, permission } })),
);
tool(
  "vikunja_project_remove_team",
  "Retire l'accès d'une équipe.",
  OBJ({ project_id: INT(), team_id: INT() }, ["project_id", "team_id"]),
  async ({ project_id, team_id }) => result("Équipe retirée", await api("DELETE", `/projects/${project_id}/teams/${team_id}`)),
);
tool("vikunja_project_shares", "Liens de partage d'un projet.", OBJ({ project_id: INT() }, ["project_id"]), async ({ project_id }) =>
  result("link shares", await api("GET", `/projects/${project_id}/shares`)),
);
tool(
  "vikunja_project_share_create",
  "Crée un lien de partage public. permission: 0 lecture,1 écriture,2 admin.",
  OBJ({ project_id: INT(), permission: INT(), password: STR("optionnel"), name: STR("nom affiché") }, ["project_id"]),
  async ({ project_id, ...b }) => result("Lien de partage créé", await api("PUT", `/projects/${project_id}/shares`, { body: b })),
);
tool(
  "vikunja_project_share_delete",
  "Supprime un lien de partage.",
  OBJ({ project_id: INT(), share_id: INT() }, ["project_id", "share_id"]),
  async ({ project_id, share_id }) => result("Lien supprimé", await api("DELETE", `/projects/${project_id}/shares/${share_id}`)),
);

// ── subscriptions ─────────────────────────────────────────────────────────────
tool(
  "vikunja_subscribe",
  "S'abonner aux notifications d'une entité. entity ∈ project, task.",
  OBJ({ entity: { type: "string", enum: ["project", "task"] }, entity_id: INT() }, ["entity", "entity_id"]),
  async ({ entity, entity_id }) => result("Abonné", await api("PUT", `/subscriptions/${entity}/${entity_id}`)),
);
tool(
  "vikunja_unsubscribe",
  "Se désabonner d'une entité. entity ∈ project, task.",
  OBJ({ entity: { type: "string", enum: ["project", "task"] }, entity_id: INT() }, ["entity", "entity_id"]),
  async ({ entity, entity_id }) => result("Désabonné", await api("DELETE", `/subscriptions/${entity}/${entity_id}`)),
);

// ── notifications ─────────────────────────────────────────────────────────────
tool("vikunja_notifications_list", "Liste les notifications.", OBJ({ page: INT(), per_page: INT() }), async (q) =>
  result("GET /notifications", await api("GET", "/notifications", { query: q })),
);
tool("vikunja_notification_mark_read", "Marque une notification comme lue.", OBJ({ id: INT() }, ["id"]), async ({ id }) =>
  result(`Notif ${id} lue`, await api("POST", `/notifications/${id}`)),
);
tool("vikunja_notifications_mark_all_read", "Marque toutes les notifications comme lues.", OBJ({}), async () =>
  result("Toutes notifs lues", await api("POST", "/notifications")),
);

// ── webhooks ──────────────────────────────────────────────────────────────────
tool("vikunja_webhook_events", "Liste les événements webhook disponibles.", OBJ({}), async () =>
  result("GET /webhooks/events", await api("GET", "/webhooks/events")),
);
tool("vikunja_webhooks_list", "Webhooks d'un projet.", OBJ({ project_id: INT() }, ["project_id"]), async ({ project_id }) =>
  result("webhooks", await api("GET", `/projects/${project_id}/webhooks`)),
);
tool(
  "vikunja_webhook_create",
  "Crée un webhook sur un projet.",
  OBJ({ project_id: INT(), target_url: STR(), events: { type: "array", items: STR() }, secret: STR("optionnel") }, ["project_id", "target_url", "events"]),
  async ({ project_id, ...b }) => result("Webhook créé", await api("PUT", `/projects/${project_id}/webhooks`, { body: b })),
);
tool(
  "vikunja_webhook_delete",
  "Supprime un webhook.",
  OBJ({ project_id: INT(), webhook_id: INT() }, ["project_id", "webhook_id"]),
  async ({ project_id, webhook_id }) => result("Webhook supprimé", await api("DELETE", `/projects/${project_id}/webhooks/${webhook_id}`)),
);

// ── reactions ─────────────────────────────────────────────────────────────────
tool(
  "vikunja_reactions_list",
  "Réactions d'une entité. kind ∈ tasks, comments.",
  OBJ({ kind: { type: "string", enum: ["tasks", "comments"] }, id: INT() }, ["kind", "id"]),
  async ({ kind, id }) => result("reactions", await api("GET", `/${kind}/${id}/reactions`)),
);
tool(
  "vikunja_reaction_add",
  "Ajoute une réaction (emoji). kind ∈ tasks, comments.",
  OBJ({ kind: { type: "string", enum: ["tasks", "comments"] }, id: INT(), value: STR("emoji") }, ["kind", "id", "value"]),
  async ({ kind, id, value }) => result("Réaction ajoutée", await api("PUT", `/${kind}/${id}/reactions`, { body: { value } })),
);
tool(
  "vikunja_reaction_delete",
  "Retire une réaction. kind ∈ tasks, comments.",
  OBJ({ kind: { type: "string", enum: ["tasks", "comments"] }, id: INT(), value: STR("emoji") }, ["kind", "id", "value"]),
  async ({ kind, id, value }) => result("Réaction retirée", await api("POST", `/${kind}/${id}/reactions/delete`, { body: { value } })),
);

// ── MCP stdio protocol (newline-delimited JSON-RPC 2.0) ───────────────────────
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
      const t = byName.get(params?.name);
      if (!t) return reply(id, { content: [{ type: "text", text: `Outil inconnu: ${params?.name}` }], isError: true });
      try {
        return reply(id, await t.run(params?.arguments || {}));
      } catch (e) {
        return reply(id, { content: [{ type: "text", text: `Erreur: ${e.message}` }], isError: true });
      }
    }
    case "ping":
      return isRequest ? reply(id, {}) : undefined;
    default:
      if (isRequest) return fail(id, -32601, `Méthode inconnue: ${method}`);
  }
}

// startup breadcrumb: stderr is the MCP debug channel; the file lets us self-diagnose spawns
let secretState = "ok";
try {
  config();
} catch {
  secretState = "absent";
}
const startupLine = `vikunja-mcp start pid=${process.pid} node=${process.version} tools=${TOOLS.length} argv=${JSON.stringify(process.argv.slice(1))} cwd=${process.cwd()} secret=${secretState}`;
process.stderr.write(startupLine + "\n");
try {
  appendFileSync(join(homedir(), ".omp", "logs", "vikunja-mcp.log"), `${new Date().toISOString()} ${startupLine}\n`);
} catch {}

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
