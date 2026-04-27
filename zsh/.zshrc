# Load oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

source $HOME/.zshconfig
source $HOME/.zshtheme
source $HOME/.zshaliases
source $HOME/.zshapps

# All following lines mush be arranged

# postgresql (macOS Homebrew)
[ -d /opt/homebrew/opt/postgresql@18/bin ] && export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"

# Default editor
export EDITOR="zed --wait"

# opencode
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"
