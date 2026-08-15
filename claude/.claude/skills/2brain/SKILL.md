---
name: 2brain
description: >-
  Mémoire persistante d'Arthur, synchronisée sur toutes ses machines (library
  Seafile `2brain`, exposée à `~/2brain`) et partagée entre tous ses agents
  (Claude Code, Codex, OMP). À UTILISER au démarrage de chaque session pour
  savoir de quoi on parle (qui est Arthur, ses projets, décisions, préférences),
  et dès qu'il parle de "ma mémoire", "ce qu'on a fait", "mes projets", d'un
  projet nommé (NS. CAPITAL, 2fleet, dotfiles…), ou veut qu'on garde une note,
  un fait, une décision, un rapport. C'est aussi là qu'on écrit les rapports et
  fichiers temporaires (plutôt que dans les repos de code). Réflexe : lire
  `~/2brain/START.md` d'abord, charger `profile/` + la couche projet, puis
  alimenter la mémoire sur déclencheur (décision / fait durable / jalon).
---

# 2brain — mémoire persistante multi-agents

Mémoire cloud-synchronisée d'Arthur, lue au démarrage et alimentée au fil de
l'eau. **Le contrat canonique est `~/2brain/START.md`** — ce skill n'est qu'un
pointeur ; en cas de doute, c'est `START.md` qui fait foi.

## Réflexe de lecture (début de session)

1. Lire **`~/2brain/START.md`**.
2. Charger **`~/2brain/profile/facts.md`** (toujours) — identité, machines,
   outils, préférences, décisions permanentes.
3. Résoudre le **projet actif** : par le dossier courant (table `Path → slug`
   dans `START.md`) ou par le nom cité (`~/2brain/projects/INDEX.md`, avec
   alias), puis charger `~/2brain/projects/<slug>/` (facts + journal récent).

## Réflexe d'écriture (pendant / fin de session)

Tu as **permission permanente** d'écrire dans `2brain` sans redemander, quand un
**déclencheur** se produit :
- **Décision** durable d'Arthur,
- **Fait durable** (URL de service, credential renouvelé, contrainte, préférence),
- **Jalon** (une unité de travail atteint un état fonctionnel).

Signal, pas bruit : ne pas journaliser les étapes de routine. En cas de doute →
`~/2brain-scratch/` (jetable), pas la mémoire. Proposer un **récap de fin de
session** avant de conclure.

### Où écrire
- Fait global → `~/2brain/profile/facts.md` ; fait projet →
  `~/2brain/projects/<slug>/facts.md`.
- Note datée → `journal/YYYY-MM-DD-HHMM-<host>.md` (une entrée = un fichier,
  anti-conflit de sync).
- Rapport à garder → `reports/`.
- **Jetable** (dumps, brouillons, sorties intermédiaires) →
  `~/2brain-scratch/<slug>/` — **local, non synchronisé, purgeable**. Les
  rapports/temporaires vont ici **plutôt que dans les repos de code**.

## Suivi des tâches — toujours via Vikunja

Méthodo de travail d'Arthur : **tout travail suivi passe par Vikunja** (serveur
MCP `vikunja`, `todo.nobrega.fr`). Réflexe : lire l'état des tâches du projet,
passer la tâche `To-Do → Doing` (bucket kanban) au démarrage, `done` à la fin,
commenter l'avancement (`vikunja_task_comment_add`) **et** loguer au journal
2brain.

**« Fais la tâche N de ce projet » :** N = l'`index` de la tâche (le #N affiché
dans l'UI), **PAS son `id` global**. Résolution : slug → projet Vikunja (colonne
« Projet Vikunja » de `projects/INDEX.md`) → tâche où `index == N` → agir sur son
`id`. Ex. « tâche 8 de 2fleet » → projet 26 → `index=8` → `id=69`.

**2fleet** (projet 26) est un orchestrateur multi-agents autonome qui gère
lui-même ses buckets (`Draft→…→Done`) et ses bots (`bot-fleet-*`) ; ne pas
piloter ses buckets à la main, mais on peut y créer/assigner des tâches aux bots
(`vikunja_task_assign`). Détails : `START.md` §3 et `projects/2fleet/facts.md`.

## Déploiements & infra — toujours via Coolify

Méthodo d'Arthur : **tout ce qui touche au déploiement/infra passe au maximum
par Coolify** (`cool.nobrega.fr`, PaaS auto-hébergé, hub central ; secret
`~/.secrets/coolify.env`, API `/api/v1/*` + `Bearer $COOLIFY_ACCESS_TOKEN`).
Utilise au **maximum les features natives de Coolify** (apps, services, DB,
déploiements, env, rollbacks, logs) ; pas de script de déploiement custom ni de
`docker run`/compose à la main quand Coolify sait le faire.

**⚠️ Déployer = action à confirmer, jamais autonome.** Lire l'état (apps,
projets, serveurs, logs) est libre. Mais **avant tout deploy/restart/stop/
changement de variable, demander à Arthur QUEL projet/app sur QUELLE machine**
(`2serv-1`, `2serv-2`, `2serv-mail`). Détails : `START.md` §4 et
`projects/coolify/facts.md`.

## Structure

```
~/2brain/START.md          contrat canonique (lire en 1er)
~/2brain/profile/          portée globale, toujours chargée : facts / journal / reports
~/2brain/projects/INDEX.md catalogue + alias (résolution + anti-doublon)
~/2brain/projects/<slug>/  facts / journal / reports
~/2brain-scratch/<slug>/   local, non synchronisé (jetable)
```

## Nouveau projet
Ajouter d'abord la ligne dans `projects/INDEX.md` (slug kebab-case + alias) pour
éviter les doublons, puis créer `projects/<slug>/{facts.md,journal/,reports/}`.

## Si la mémoire est absente
`~/2brain` ou `START.md` manquant = machine pas encore amorcée. La lib se
synchronise via le token Seafile déjà présent dans `~/.secrets` : relancer
`setup-arch.sh` / `setup.sh` (section « 2brain »). Ne pas recréer l'arbo à la
main sur une machine non synchronisée.

## Sécurité
`2brain` contient de la mémoire de travail, pas des secrets (ceux-ci restent
dans `~/.secrets`). Ne jamais y recopier un token/mot de passe en clair.
