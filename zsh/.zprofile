# Homebrew — macOS (/opt/homebrew, /usr/local) and Linux (/home/linuxbrew/.linuxbrew)
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
  if [ -x "$_brew" ]; then
    eval "$("$_brew" shellenv zsh)"
    break
  fi
done
unset _brew

# rbenv
if command -v rbenv &>/dev/null; then
  eval "$(rbenv init - --no-rehash zsh)"
fi
