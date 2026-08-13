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

### Drive (Seafile) — the one manual step

The skills read their API token from `~/.secrets/seafile.env` (never committed). Because
that file is itself synced *inside* the drive, a fresh machine can't fetch it from the
drive yet — you must drop it once, out-of-band:

```bash
mkdir -p ~/.secrets
printf 'SEAFILE_URL=https://drive.nobrega.fr\nSEAFILE_TOKEN=<token>\n' > ~/.secrets/seafile.env
# get <token> from another synced machine, a password manager, or:
#   curl -d 'username=<you>&password=<pw>' https://drive.nobrega.fr/api2/auth-token/
```

Then run `./setup-arch.sh` (or `./setup.sh`): with the token present it installs `seaf-cli`
(AUR on Arch; manual on macOS), initializes the sync client, and pulls the personal
libraries (`Ma bibliothèque`, `Pro`, `Arthur`). Encrypted libraries still need their
per-library password. Everything else — API access, uploads, share links — works from the
token alone, no sync client required. `~/.secrets` is only symlinked into the drive when it
doesn't already exist and the target is present (no dangling links, no clobbering).


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
