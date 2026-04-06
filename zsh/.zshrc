# Load oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

source $HOME/.zshconfig
source $HOME/.zshtheme
source $HOME/.zshaliases
source $HOME/.zshapps

# All following lines mush be arranged


# bun completions
[ -s "/Users/arthur/.bun/_bun" ] && source "/Users/arthur/.bun/_bun"
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Default editor
export EDITOR="zed --wait"

# opencode
export PATH=/Users/arthur/.opencode/bin:$PATH
