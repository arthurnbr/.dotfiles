# Instructions globales (Codex)

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

Si `~/2brain/START.md` est absent (machine pas amorcée), relancer `setup*.sh`
(la lib se synchronise via le token déjà présent dans `secrets`).

## Dotfiles

Ce fichier est géré par GNU Stow depuis `~/.dotfiles` (package `claude`,
source : `~/.dotfiles/claude/.codex/AGENTS.md`). Après modification, commit +
push dans `~/.dotfiles` pour synchroniser les autres machines.
