# Homebrew (macOS)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
fi

# rbenv
if command -v rbenv &>/dev/null; then
  eval "$(rbenv init - --no-rehash zsh)"
fi
