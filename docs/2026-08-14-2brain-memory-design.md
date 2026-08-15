# 2brain — Persistent multi-agent memory (design)

Date: 2026-08-14
Status: approved (design) → implementation
Author: Arthur + agent (brainstorming session)

## Goal

A persistent memory that any AI agent (Claude Code, Codex, OMP; later online
ChatGPT/Claude via MCP), on any of Arthur's machines, knows how to **read at
startup** and **feed as it works**. The memory is cloud-synced, well-organized,
and curated. Agents also get a clear place to drop reports/temporary files
instead of polluting code repos.

## Core decisions (from brainstorming)

1. **What = both, separated (C).** A layer of stable *facts* and a dated
   *journal*, kept distinct.
2. **Support = a new Seafile library `2brain` (A).** Synced everywhere like the
   `secrets` lib, exposed at a stable path `~/2brain`. Writing a file →
   propagated in seconds, **no commit**. Version history server-side. Plain
   Markdown, zero-dependency.
3. **Reflex = one canonical `START.md` + thin per-agent pointers (B).** Single
   source of truth; each agent is wired by a one-line pointer. MCP layers onto
   the same tree later.
4. **Two organizing axes (scope × type).**
   - Scope: **global `profile/`** (always loaded) + **`projects/<slug>/`**
     (loaded on demand).
   - Type: `facts` · `journal` · `reports` (+ `scratch`, see 6).
5. **Project resolution = both (C).** Auto from `cwd`/repo via a table in
   `START.md`; otherwise by **name/alias** via `projects/INDEX.md`. INDEX also
   serves as an anti-duplicate catalog.
6. **Scratch = local, unsynced (B).** Throwaway work lives in
   `~/2brain-scratch/<slug>/`, never synced, freely purgeable. The `2brain` lib
   stays 100% durable/curated.
7. **Writing = disciplined hybrid (C).** Autonomous on triggers
   (decision / durable fact / milestone), **plus** an end-of-session recap the
   agent proposes before concluding. Quality filter, no drift.
8. **Task tracking = always via Vikunja.** Part of the methodology, documented
   in `START.md` §3. Every tracked piece of work is a Vikunja task; the agent
   reads state, moves it `To-Do → Doing → Done` (kanban buckets), and logs
   progress (task comment + 2brain journal). Project slugs map to Vikunja
   project ids in `INDEX.md` (`ns-capital`→16, `2fleet`→26). Key gotcha:
   **"task N" = the task `index` (the #N shown in the UI), not the global
   `id`** — resolve slug → project → task where `index==N` → act on its `id`.
   `2fleet` (26) is Arthur's autonomous multi-agent orchestrator that manages
   its own buckets/bots (`bot-fleet-*`); agents don't drive its buckets by hand
   but may create/assign tasks to its bots.
9. **Deployments & infra = always via Coolify.** Documented in `START.md` §4.
   Coolify (`cool.nobrega.fr`) is Arthur's self-hosted PaaS and the central hub
   that deploys the rest of the infra. Agents use Coolify's native features to
   the maximum (no custom deploy scripts / hand-run containers when Coolify can
   do it). Reading state is free; **any deploy/restart/stop/env change is a
   confirm-first action — the agent must always ask Arthur which project/app on
   which machine (`2serv-1/2/mail`) before acting, never autonomously.**
   Modeled as its own 2brain project `coolify` (facts + servers + project map).

## Structure

```
~/2brain/                        (Seafile lib, synced everywhere)
  START.md                       reflex + map. Read FIRST, always.
  profile/                       GLOBAL scope — always loaded
    facts.md                     who Arthur is, prefs, machines, tools, permanent decisions
    journal/                     cross-project dated thread
    reports/                     global keep-worthy outputs
  projects/
    INDEX.md                     catalog + aliases (name resolution, anti-dup)
    <slug>/                      kebab-case: ns-capital, 2fleet, dotfiles, 2brain, …
      facts.md                   stable project facts
      journal/                   what we did, dated
      reports/                   write-ups, analyses to keep

~/2brain-scratch/<slug>/         LOCAL only, never synced, purgeable
```

## Reflex — READ

At startup, every agent:
1. Reads `~/2brain/START.md`.
2. Loads `profile/` (always).
3. Resolves the active project: (a) match `cwd`/repo against the path→slug table
   in `START.md`; else (b) when Arthur names a project, resolve via
   `projects/INDEX.md` (names + aliases).
4. Loads `projects/<slug>/`.

## Reflex — WRITE

- **Autonomous on triggers** (defined in `START.md`): a **decision**, a
  **durable fact**, a **milestone** → the agent writes on its own, no asking.
- **End-of-session recap**: before concluding meaningful work, the agent
  proposes "here is what I'm recording in 2brain" → Arthur validates.
- **Reports & work files**: useful output → `projects/<slug>/reports/`;
  throwaway → `~/2brain-scratch/<slug>/`. Explicitly instead of code repos.

## Journal file naming (anti-conflict)

One file per entry: `journal/YYYY-MM-DD-HHMM-<host>.md`. Sorts chronologically,
avoids Seafile `SFConflict` when two machines write the same day, keeps each
note atomic.

## Per-agent wiring (thin pointers)

`START.md` is the single source. Each agent points to it with one line, laid
down by `setup*.sh` (same pattern as skills/MCP):
- **Claude Code** → block in `CLAUDE.md`: "At startup, read `~/2brain/START.md`."
- **Codex** → same line in `~/.codex/AGENTS.md`.
- **OMP** → a `2brain` skill (auto-discovered) pointing at `START.md`.
- **New-machine bootstrap** → `setup*.sh` syncs the `2brain` lib (token already
  in `secrets`), lays down `~/2brain` + the pointers. No chicken-and-egg.

## MCP — deferred (v2)

Not built in v1. When wiring online ChatGPT/Claude: a Node zero-dep MCP server
exposes `memory_read` / `memory_search` / `memory_append` over the **same**
`2brain` tree. v1 is shaped so it grafts on without changes.

## Verification

- `2brain` lib created + synced (file posted here visible via Seahub API).
- The 3 agents resolve `START.md` (plant a fact in `profile/facts.md`, agent
  restitutes it).
- A real write cycle: record *this design* as 2brain's first content (project
  `2brain`, a milestone in journal, this spec as a report).
