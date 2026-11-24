# Instructions globales (Codex, OMP)

## Mémoire persistante (2brain)

Arthur a une **mémoire persistante, synchronisée sur toutes ses machines** et
partagée entre tous ses agents (Claude Code, Codex, OMP). Elle vit dans la
library Seafile `2brain`, exposée à **`~/2brain`** (synchronisée comme
`~/.secrets`, écriture propagée en secondes, sans commit).

**Au démarrage de CHAQUE session, tu DOIS :**
1. Lire **`~/2brain/START.md`** — le contrat canonique (comment lire la mémoire
   et comment l'alimenter). Source unique de vérité ; ce fichier n'est qu'un
   pointeur.
2. Charger `~/2brain/profile/facts.md` (toujours), puis la couche projet
   (`~/2brain/projects/<slug>/`) résolue par le dossier courant ou par le nom
   cité (cf. `~/2brain/projects/INDEX.md`).

**Pendant / à la fin du travail**, alimente-la de toi-même sur déclencheur
(décision, fait durable, jalon) et propose un récap avant de conclure — règles
exactes dans `START.md`.

**Rapports & fichiers temporaires** : dans `2brain` (à garder →
`projects/<slug>/reports/`) ou `~/2brain-scratch/<slug>/` (jetable, non
synchronisé) — **jamais en vrac dans un repo de code**.

**Suivi des tâches — deux systèmes, ne jamais les mélanger** (détails :
`START.md` §3) :
- **Eduvia (pro)** : dossier `~/Documents/eduvia*` (repo, worktrees
  `eduvia-envs`, `eduplanner`, `herdr-eduvia`) ou sujet Eduvia (tâche `EDU-n`,
  créneau, CR, PR Eduvia) → **GDP Eduvia = eduplanner** (`planner.eduvia.dev`),
  outils `gdp_*` (MCP `gdp`) + skill `gdp`. **Jamais Vikunja.** Plane est
  remplacé par eduplanner : ne plus l'utiliser.
- **Tout le reste (perso, NS. CAPITAL, 2fleet, dotfiles…)** → **Vikunja**
  (`todo.nobrega.fr`, MCP `vikunja`) : lis l'état, `To-Do→Doing→done`,
  commente + logue au journal 2brain. « Tâche N d'un projet » = l'`index` (#N
  affiché), pas l'`id` global — projet résolu via `~/2brain/projects/INDEX.md`.

**Déploiements & infra** (détails : `START.md` §4) : perso → **Coolify
`cool.nobrega.fr`** (secret `~/.secrets/coolify.env`), au maximum avec ses
features natives. Eduvia → process du repo concerné (tags `r/prod/*`, Coolify
Eduvia `coolify.eduvia.dev`), jamais le Coolify perso. Lire l'état : libre.
**Déployer/redémarrer/arrêter = feu vert explicite d'Arthur (quel projet, quelle
machine) — jamais autonome.**

**Livrer un document** : quand tu transmets un fichier à Arthur, donne **le
chemin local** (s'il est sur l'hôte) **et** un **lien de téléchargement Seafile**
(sinon). Il dira si l'un est superflu. Le lien est **public, téléchargeable sans
connexion** (voulu). Lien possible seulement pour un fichier dans une lib
Seafile — `~/2brain/…` en est une ; le scratch n'est jamais synchronisé, donc
pour partager un fichier, copie-le d'abord dans `~/2brain/` (le livrable précis,
pas tout le scratch). Détails : `START.md` §5.

Si `~/2brain/START.md` est absent (machine pas amorcée), relancer `setup*.sh`
(la lib se synchronise via le token déjà présent dans `secrets`).

## Dotfiles

Ce fichier est géré par GNU Stow depuis `~/.dotfiles` (package `claude`,
source : `~/.dotfiles/claude/.codex/AGENTS.md`) ; OMP le lit via
`~/.omp/agent/AGENTS.md` (symlink du package `omp`). Après modification,
commit + push dans `~/.dotfiles` pour synchroniser les autres machines.
