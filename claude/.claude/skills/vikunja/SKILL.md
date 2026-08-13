---
name: vikunja
description: >-
  Piloter l'instance Vikunja auto-hébergée d'Arthur (gestion de tâches / todo /
  kanban / projets), sur https://todo.nobrega.fr. À UTILISER dès qu'Arthur parle
  de "mes tâches", "ma todo", "mon kanban", "mes projets", Vikunja, ajouter/cocher/
  planifier une tâche, une échéance, une priorité, un label, un rappel — même sans
  citer "Vikunja". Le token API est dans `~/.secrets/vikunja.env` (VIKUNJA_URL,
  VIKUNJA_TOKEN), synchronisé via Seafile. Préférer les outils MCP `vikunja_*`
  quand ils sont disponibles ; sinon l'API REST /api/v1 (auth Bearer).
---

# Vikunja — gestion de tâches (todo.nobrega.fr)

Instance **v2.5.0**, self-hosted. Le token appartient au compte bot **`bot-assistant-bot`**
(id 2, propriété de l'admin id 1). Link-sharing, pièces jointes (20 Mo), CalDAV activés.

## Outils MCP (à préférer)

Un serveur **MCP** maison expose **~80 outils typés** couvrant l'intégralité de l'API +
une échappatoire universelle. Code : `~/.claude/mcp-servers/vikunja/server.mjs` (zéro
dépendance, `node`/`bun`), synchronisé via dotfiles, config `mcp.example.json` à côté.
Le serveur charge lui-même `~/.secrets/vikunja.env`.

- **`vikunja_request(method, path, body?, query?)`** — échappatoire : n'importe quel
  endpoint (couvre 100% de l'API, y compris admin/migrations). À utiliser si aucun outil
  typé ne convient.
- **Projets** : `vikunja_projects_list`, `_project_get/_create/_update/_delete/_duplicate`.
- **Tâches** : `vikunja_tasks_list` (filtre puissant), `_project_tasks`, `_task_get/_create/
  _update/_delete/_duplicate`, `_tasks_bulk_update`, `_task_set_position`.
- **Sous-ressources tâche** : labels (`_task_add_label`…), assignés (`_task_assign`…),
  commentaires (`_task_comment_add`…), relations (`_task_relation_add`…), pièces jointes
  (`_task_attachment_upload`…).
- **Kanban** : `vikunja_project_views`, `_view_create`, `_buckets_list`, `_bucket_create`,
  `_task_set_bucket`.
- **Labels**, **filtres sauvegardés**, **équipes**, **partages** (users/teams/liens),
  **abonnements**, **notifications**, **webhooks**, **réactions** — un groupe d'outils chacun.

## Auth (API directe si besoin)

- Base : `https://todo.nobrega.fr/api/v1`
- Header : **`Authorization: Bearer <token>`** (token `tk_...`).
- Token : `~/.secrets/vikunja.env` (`VIKUNJA_URL`, `VIKUNJA_TOKEN`). Lis-le d'abord ; ne
  JAMAIS recopier le token en clair. Absent → demander à Arthur (cf. seafile secrets).
- OpenAPI complet : `GET /api/v1/docs.json` (126 endpoints, 98 modèles).

```bash
KEY=$(grep -E '^VIKUNJA_TOKEN=' ~/.secrets/vikunja.env | cut -d= -f2)
curl -s -H "Authorization: Bearer $KEY" "https://todo.nobrega.fr/api/v1/projects"
```

## Concepts clés (v2.5)

- **Projects** remplacent les anciens namespaces + listes ; ils sont **imbriquables**
  (`parent_project_id`). Les filtres sauvegardés apparaissent comme pseudo-projets à **id
  négatif**.
- Une tâche est créée dans un projet : `PUT /projects/{id}/tasks`. Mise à jour :
  `POST /tasks/{id}`.
- **Priorité** : 0 aucune, 1 basse, 2 moyenne, 3 haute, 4 urgente, 5 DO NOW.
- **Dates** : RFC3339 (`2026-08-20T09:00:00Z`) ; chaîne vide efface. `percent_done` ∈ 0..1.
- **Vues** par projet : `list`, `gantt`, `table`, `kanban`. Les **buckets kanban sont par
  vue** : `GET /projects/{id}/views/{view}/buckets`.
- **Relations** (`relation_kind`) : subtask, parenttask, related, duplicateof, duplicates,
  blocking, blocked, precedes, follows, copiedfrom, copiedto.
- **Permissions** de partage : 0 lecture, 1 écriture, 2 admin.

## Filtres (paramètre `filter` de la liste de tâches)

Syntaxe : `champ op valeur`, combinés par `&&` / `||`. Opérateurs : `= != > >= < <= like in`.
Champs utiles : `done`, `priority`, `percent_done`, `due_date`, `start_date`, `labels`,
`assignees`, `project`. Exemples :

- `done = false && priority >= 3`
- `due_date < now && done = false`
- `labels in 3,4`
- `assignees in bot-assistant-bot`

`sort_by`/`order_by` acceptent plusieurs champs. `s=` pour la recherche plein-texte.

## Sécurité

Instance perso, compte bot. Lectures libres ; créations/mises à jour = flux normal. Les
suppressions (tâche, projet, label) sont des opérations courantes ici — pas de garde-fou,
mais rester précis sur les ids. Les endpoints `admin/*` existent (via `vikunja_request`)
mais le token bot n'est probablement pas admin (→ 403).
