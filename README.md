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
| `claude` | Claude Code global `CLAUDE.md` | all |
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
