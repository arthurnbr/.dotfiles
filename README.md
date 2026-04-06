# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Description |
|---------|-------------|
| `zsh` | Shell config, aliases, theme, plugins |
| `tmux` | Tmux config + git status script |
| `ghostty` | Ghostty terminal (Tokyo Night theme) |
| `zed` | Zed editor settings, keymaps, tasks |
| `git` | Git config + global ignore |
| `karabiner` | Karabiner-Elements key remappings |

## New machine setup

```bash
git clone <repo-url> ~/Documents/.dotfiles
cd ~/Documents/.dotfiles
chmod +x setup.sh
./setup.sh
```

## Stow a single package

```bash
cd ~/Documents/.dotfiles
stow -v --target="$HOME" <package>
```

## Unstow (remove symlinks)

```bash
cd ~/Documents/.dotfiles
stow -v --target="$HOME" -D <package>
```
