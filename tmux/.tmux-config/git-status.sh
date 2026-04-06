#!/bin/bash
# Git info for tmux status bar
cd "$1" 2>/dev/null || exit 0

# Check if in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")

staged=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
unstaged=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

added=$(git diff --cached --numstat 2>/dev/null | awk '{s+=$1} END {print s+0}')
removed=$(git diff --cached --numstat 2>/dev/null | awk '{s+=$2} END {print s+0}')
mod_added=$(git diff --numstat 2>/dev/null | awk '{s+=$1} END {print s+0}')
mod_removed=$(git diff --numstat 2>/dev/null | awk '{s+=$2} END {print s+0}')

total_plus=$(( added + mod_added ))
total_minus=$(( removed + mod_removed ))

# Build output
out="#[fg=#a9b1d6] ${repo}#[default]"
out+=" #[fg=#bb9af7,bold] ${branch}#[default]"

changes=""
if (( total_plus > 0 )); then
  changes+="#[fg=#9ece6a]+${total_plus}#[default]"
fi
if (( total_minus > 0 )); then
  [[ -n "$changes" ]] && changes+=" "
  changes+="#[fg=#f7768e]-${total_minus}#[default]"
fi
if (( untracked > 0 )); then
  [[ -n "$changes" ]] && changes+=" "
  changes+="#[fg=#e0af68]?${untracked}#[default]"
fi

if [[ -n "$changes" ]]; then
  out+=" ${changes}"
fi

echo "$out"
