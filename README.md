# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Description | Platforms |
|---------|-------------|-----------|
| `zsh` | Shell config, aliases, theme, plugins | all |
| `tmux` | Tmux config + git status script | all |
| `ghostty` | Ghostty terminal (Tokyo Night theme) | all |
| `zed` | Zed editor settings, keymaps, tasks | all |
| `git` | Git config + global ignore | all |
| `starship` | Starship prompt config | all |
| `claude` | Global `CLAUDE.md` + OMP/Claude skills (`seafile`, `dolibarr`) | all |
| `karabiner` | Karabiner-Elements key remappings | macOS |
| `hypr` | Hyprland personal configs (bindings, monitors, input, etc.) | Linux (Omarchy) |
| `waybar` | Waybar config + style | Linux (Omarchy) |
| `keyd` | System-wide key remapping (Alt+HJKL → arrows). Not stowed — `setup-arch.sh` deploys `keyd/default.conf` to `/etc/keyd/` and enables the daemon. | Linux |

## New machine setup

```bash
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
chmod +x setup.sh setup-arch.sh

# macOS
./setup.sh

# Arch Linux / Omarchy
./setup-arch.sh
```

## Skills (OMP) & Seafile drive

Custom OMP/Claude skills (`seafile`, `dolibarr`, …) live in the `claude` package at
`claude/.claude/skills/<name>/SKILL.md` and travel through git + stow. `setup*.sh` links
them into OMP's native skill root:

- `stow claude` → `~/.claude/skills/<name>`
- `~/.omp/agent/skills` → `~/.claude/skills` (OMP native provider; no toggle needed)

OMP discovers skills **at startup** — restart OMP (or open a new session) after setup for
newly added skills to appear.

### Drive (Seafile)

Two access modes (see the `seafile` skill + `claude/.claude/skills/seafile/libraries.md`):

- **`secrets` library** — a small dedicated library holding every token/`.env` at its root.
  Auto-synced on **every** machine and exposed at `~/.secrets` (symlink → its checkout). This
  is where `~/.secrets/seafile.env` comes from.
- **Content libraries** (`Ma bibliothèque`, `Pro`, `Arthur`, …) — synced **on demand** into
  `~/Documents/<lib>`, only where you want them. When a lib isn't synced, the agent reads it
  via the Seahub API (no full sync needed).

**Fresh-machine bootstrap** (the one manual step — chicken-and-egg: the token lives *inside*
the `secrets` lib, so it can't be fetched from the drive before the drive is reachable).
Provide the token once via the environment, then re-run setup:

```bash
SEAFILE_URL=https://drive.nobrega.fr SEAFILE_TOKEN=<token> ./setup-arch.sh   # or ./setup.sh
# get <token> from another machine (~/.secrets/seafile.env), a password manager, or:
#   curl -d 'username=<you>&password=<pw>' https://drive.nobrega.fr/api2/auth-token/
```

`setup*.sh` then installs `seaf-cli` (AUR package `seafile` on Arch; manual on macOS),
initializes the client, syncs **only** the `secrets` lib, and points `~/.secrets` at it
(defensively — never clobbering a real `~/.secrets`, never a dangling link). Content
libraries are never auto-synced; sync one with `seaf-cli download … -d ~/Documents` (see
`libraries.md`).


## Stow a single package

```bash
cd ~/.dotfiles
stow -v --target="$HOME" <package>
```

## Unstow (remove symlinks)

```bash
cd ~/.dotfiles
stow -v --target="$HOME" -D <package>
```
