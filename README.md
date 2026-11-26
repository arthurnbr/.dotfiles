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
| `herdr` | herdr (TUI) config + herdr-app keys & settings. Les mods herdr-app d'Eduvia (`eduvia-servers`, …) vivent dans le repo eduvia : `tools/herdr/install.sh`. | all |
| `claude` | Global `CLAUDE.md` + Codex `AGENTS.md` + OMP/Claude skills (`seafile`, `dolibarr`, `vikunja`, `2brain`, …) + local MCP servers (`dolibarr`, `vikunja`) | all |
| `omp` | OMP `models.yml` (custom providers, e.g. `eduvia`). API keys are read at runtime from `~/.secrets/*.env`, never committed. | all |
| `karabiner` | Karabiner-Elements key remappings | macOS |
| `hypr` | Hyprland personal configs — Lua overrides (bindings, input, look'n'feel) + `hyprsunset.conf` | Linux (Omarchy) |
| `keyd` | System-wide key remapping (Alt+HJKL → arrows). Not stowed — `setup-arch.sh` deploys `keyd/default.conf` to `/etc/keyd/` and enables the daemon. | Linux |

## New machine setup

```bash
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
chmod +x setup.sh setup-arch.sh setup-debian.sh

# macOS
./setup.sh

# Arch Linux / Omarchy
./setup-arch.sh

# Debian (headless server, e.g. mail VPS)
./setup-debian.sh
```

On a **remote-eduvia container** (Eduvia dev box, detected via `/etc/remote-eduvia`),
`setup-debian.sh` leaves the platform-owned pieces alone: `~/.omp/agent/models.yml` (per-dev
AI key, rewritten by `remote-eduvia-admin ai-sync`) is not stowed, and `~/.zshrc.local`
sources `/etc/profile.d/remote-eduvia.sh` (PATH, `BROWSER=open`, `NODE_OPTIONS`…).
Agent SSH access from Arthur's machines: `ssh remote-arthur` (key in the container's
`authorized_keys`, jump via `secondary`).

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

## 2brain — persistent multi-agent memory

A cloud-synced memory shared across machines **and** agents (Claude Code, Codex, OMP; later
online agents via MCP). Any agent reads it at session start and feeds it as it works, so it
always knows Arthur's context (identity, projects, decisions, preferences) and has a place to
drop reports/temp files instead of polluting code repos.

- **Storage** — a dedicated Seafile library `2brain`, auto-synced on **every** machine like
  `secrets`, exposed at **`~/2brain`** (symlink → its checkout). Writes propagate in seconds,
  no commit. Throwaway work goes to `~/2brain-scratch/` (local, never synced).
- **Canonical contract** — `~/2brain/START.md` is the single source of truth (how to read the
  memory, how to feed it). Per-agent files are thin pointers: the `2brain` block in `CLAUDE.md`,
  the same in Codex `AGENTS.md`, and the OMP `2brain` skill.
- **Structure** — `profile/` (global, always loaded) + `projects/<slug>/`, each with
  `facts` / `journal` / `reports`. `projects/INDEX.md` is the catalog + alias map.
- **Bootstrap** — `setup*.sh` syncs the `2brain` lib (token already in `secrets`), lays down
  `~/2brain` + `~/2brain-scratch`. Design spec: `docs/2026-08-14-2brain-memory-design.md`.

## Wallpaper Engine (live wallpapers, Omarchy)

`setup-arch.sh` (section 11) installs the [`omarchy-wallpaper-engine`](https://github.com/dkgamer02ai/omarchy-wallpaper-engine)
plugin + the `linux-wallpaperengine-git` AUR renderer, enables the plugin and
adds the FPS watcher to Hyprland autostart. The plugin wires up the `omarchy-we`
CLI, the **menu → Style → Wallpaper Engine** row (the Omatrix dial) and a
theme-set hook. Two pieces live in this repo and travel via stow:

- `hypr/bindings.lua` — **SUPER+CTRL+SPACE** opens the Omatrix dial (overrides
  Omarchy's default *Background switcher* on that key).
- `bin/.local/bin/omarchy-we-fps-watch` — caps the live wallpaper at **30 fps**
  under the `power-saver` power profile, **60 fps** otherwise (relaunches the
  renderer on profile change, only while a wallpaper is running).

**Manual, per-machine** (not scriptable): install **Wallpaper Engine** on Steam
(app 431960) and subscribe to some *scene*/*video* wallpapers — they land in
`~/.local/share/Steam/steamapps/workshop/content/431960/`. Then
`omarchy-we list` / the dial will show them. `web` wallpapers render poorly on
Linux. Usage: `omarchy-we set <n|id|title>`, `next`/`prev`/`random`, `stop`.


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
