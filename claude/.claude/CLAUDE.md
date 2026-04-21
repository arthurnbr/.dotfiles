# Global Instructions

## Dotfiles (stow + git)

Ce fichier (`~/.claude/CLAUDE.md`) est un **symlink** géré par [GNU Stow](https://www.gnu.org/software/stow/) depuis mon repo dotfiles :

- **Repo** : `~/Documents/.dotfiles` (remote: `git@github.com:arthurnbr/.dotfiles.git`)
- **Source réelle** : `~/Documents/.dotfiles/claude/.claude/CLAUDE.md`
- **Setup** : `~/Documents/.dotfiles/setup.sh` (le package `claude` est dans la liste `PACKAGES`)

Je travaille **de la même manière sur tous mes OS** : chaque machine clone le repo dotfiles dans `~/Documents/.dotfiles` puis exécute `setup.sh`, qui fait `stow --target="$HOME" claude` (entre autres).

**Règles pour Claude** :
- Toute modification de `~/.claude/CLAUDE.md` édite en réalité le fichier du repo dotfiles via le symlink — c'est voulu.
- Après une modification, **commit et push dans le repo dotfiles** (`~/Documents/.dotfiles`), sans demander confirmation, pour que la config soit synchronisée sur mes autres machines. Ne jamais laisser un changement non commité dans ce repo.
- Si tu ajoutes un nouveau fichier de config à gérer globalement (pas seulement `CLAUDE.md`), place-le dans `~/Documents/.dotfiles/<package>/<chemin-relatif-à-HOME>/` et, si c'est un nouveau package, ajoute-le à `PACKAGES` dans `setup.sh` et re-stow.


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