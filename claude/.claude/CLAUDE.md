# Global Instructions

## Dotfiles (stow + git)

Ce fichier (`~/.claude/CLAUDE.md`) est un **symlink** géré par [GNU Stow](https://www.gnu.org/software/stow/) depuis mon repo dotfiles :

- **Repo** : `~/.dotfiles` (remote: `git@github.com:arthurnbr/.dotfiles.git`)
- **Source réelle** : `~/.dotfiles/claude/.claude/CLAUDE.md`
- **Setup** : `~/.dotfiles/setup.sh` (le package `claude` est dans la liste `PACKAGES`)

Je travaille **de la même manière sur tous mes OS** : chaque machine clone le repo dotfiles dans `~/.dotfiles` puis exécute `setup.sh` (macOS) ou `setup-arch.sh` (Arch / Omarchy), qui fait `stow --target="$HOME" claude` (entre autres).

**Règles pour Claude** :
- Toute modification de `~/.claude/CLAUDE.md` édite en réalité le fichier du repo dotfiles via le symlink — c'est voulu.
- Après une modification, **commit et push dans le repo dotfiles** (`~/.dotfiles`), sans demander confirmation, pour que la config soit synchronisée sur mes autres machines. Ne jamais laisser un changement non commité dans ce repo.
- Si tu ajoutes un nouveau fichier de config à gérer globalement (pas seulement `CLAUDE.md`), place-le dans `~/.dotfiles/<package>/<chemin-relatif-à-HOME>/` et, si c'est un nouveau package, ajoute-le à `PACKAGES` dans `setup.sh` et re-stow.

## Mémoire persistante (2brain)

J'ai une **mémoire persistante, synchronisée sur toutes mes machines** et partagée entre tous mes agents (Claude Code, Codex, OMP). Elle vit dans la library Seafile `2brain`, exposée à **`~/2brain`** (synchronisée comme `~/.secrets`, écriture propagée en secondes, sans commit).

**Au démarrage de CHAQUE session, tu DOIS :**
1. Lire **`~/2brain/START.md`** — c'est le contrat canonique (comment lire la mémoire et comment l'alimenter). Source unique de vérité ; ce bloc n'est qu'un pointeur.
2. Charger `~/2brain/profile/facts.md` (toujours), puis la couche projet (`~/2brain/projects/<slug>/`) résolue par le dossier courant ou par le nom que je cite (cf. `projects/INDEX.md`).

**Pendant/à la fin du travail**, alimente-la de toi-même quand un déclencheur se produit (décision, fait durable, jalon), et propose un récap avant de conclure — règles exactes dans `START.md`.

**Rapports & fichiers temporaires** : écris-les dans `2brain` (utile à garder → `projects/<slug>/reports/`) ou dans `~/2brain-scratch/<slug>/` (jetable, non synchronisé) — **jamais en vrac dans un repo de code**.

**Suivi des tâches — toujours via Vikunja** (serveur MCP `vikunja`, `todo.nobrega.fr`) : tout travail suivi passe par Vikunja ; lis l'état, passe `To-Do→Doing` puis `done`, commente + logue au journal 2brain. « Tâche N d'un projet » = l'`index` (le #N affiché), pas l'`id` global — résous le projet via `~/2brain/projects/INDEX.md`. Détails et cas 2fleet : `START.md` §3.

**Déploiements & infra — toujours via Coolify** (`cool.nobrega.fr`, secret `~/.secrets/coolify.env`) : utilise au **maximum les features natives de Coolify**, pas de déploiement manuel/script custom quand Coolify sait le faire. Lire l'état : libre. **Déployer/redémarrer/arrêter = demande TOUJOURS à Arthur quel projet sur quelle machine avant d'agir — jamais autonome.** Détails : `START.md` §4.

**Livrer un document** : quand tu me transmets un fichier, donne-moi **le chemin local** (si je suis sur l'hôte) **et** un **lien de téléchargement Seafile** (sinon, pour faciliter l'échange). Je te dirai si l'un des deux est superflu. Un lien n'est possible que pour un fichier dans une lib Seafile — `~/2brain/…` en est une (dépose les livrables là). Détails : `START.md` §5.

Si `~/2brain/START.md` est absent (machine pas encore amorcée), relancer `setup*.sh` (la lib se synchronise via le token déjà présent dans `secrets`).


## Tmux Window Naming

When running inside a tmux session, rename the current tmux window to a short name (2-4 words max) reflecting the current task or modifications being made.

**IMPORTANT**: you MUST rename the window **every time the focus of the work changes** — not just once at the start of the conversation. As soon as you switch to a different task, feature, bug, or area of the codebase, update the window name immediately to reflect the new focus. A stale window name is worse than no name — it misleads. Be proactive: if in doubt, rename.

Before renaming, check if the window has a custom name set by the user (i.e. not the default shell name like "zsh", "bash", or "claude"). If it already has a custom name, do not rename it.

```bash
# Check current window name before renaming
tmux display-message -p '#W'
# Only rename if the name is a default one (zsh, bash, claude, etc.)
tmux rename-window "short-task-name"
```

## Herdr (terminal multiplexer)

Arthur utilise **herdr** (`~/.local/bin/herdr`) comme terminal workspace manager (à la place de tmux natif). Commandes utiles :

```bash
# Lister les panes
herdr pane list

# Splitter un pane (créer un nouveau à côté)
herdr pane split <pane_id> --direction right|down [--cwd PATH] [--focus]

# Envoyer du texte / des touches dans un pane
herdr pane send-text <pane_id> "<command>"
herdr pane send-keys <pane_id> Enter

# Lire le contenu d'un pane
herdr pane read <pane_id> [--lines N]

# Renommer / fermer un pane
herdr pane rename <pane_id> "label"
herdr pane close <pane_id>

# Exécuter une commande dans un pane
herdr pane run <pane_id> "<command>"
```

**Tabs** (préféré aux panes pour les processus longs) :

```bash
herdr tab create [--cwd PATH] [--label TEXT] [--no-focus]
herdr tab list
herdr tab close <tab_id>
```

**Pour lancer des serveurs ou processus longs** : créer une **tab** (pas un pane), la nommer, et y envoyer la commande via `herdr pane send-text <root_pane_id>` — ne pas bloquer le pane agent.