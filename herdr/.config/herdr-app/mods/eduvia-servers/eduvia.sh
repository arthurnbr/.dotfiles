#!/usr/bin/env bash
# The dev servers (front, back, histoire) of an Eduvia checkout, for the eduvia-servers
# herdr-app mod. Runs on the machine the checkout is on (the mod copies it to
# ~/.cache/eduvia-servers/ on remote machines). Linux: ss, /proc; needs hc and jq.
#
#   eduvia.sh root <folder>...      the Eduvia checkout of the first folder that is in one
#   eduvia.sh status <checkout>     its servers, one tab-separated record per line:
#       R root | V name value (.eduvia-env) | X server port (where it starts)
#       L pid ports addresses cwd ancestor-pids command (a listening process in the checkout)
#       P server action since (an action under way) | E server message (the last one failed)
#       F server file (a log file) | M tool (missing here)
#   eduvia.sh ctl start|stop|restart <checkout> <server> <how> <terminal|-> <pid|->
#       how: managed (its own terminal, from here), inplace (a shell's foreground program),
#       external (anything else listening), none (not running). Runs in its own hc terminal
#       (hc run --bg): it waits, and outlives the popover that started it.
#   eduvia.sh serve managed|inplace <checkout> <server>
#       managed: loops in its own terminal (labels eduvia.next=restart|stop drive it; a
#       crash waits there labelled eduvia.failed=<code>). inplace: once, in the person's shell.
set -u
self=$(readlink -f "$0")
state_dir=${XDG_RUNTIME_DIR:-/tmp/eduvia-$(id -u)}/eduvia-servers
SERVERS="front back histoire"

checkout_of() {
  local d=$1
  while [ -n "$d" ] && [ "$d" != / ]; do
    if [ -f "$d/tools/env/eduvia-env" ] && [ -d "$d/backend" ] && [ -d "$d/frontend" ]; then
      printf '%s\n' "$d"
      return 0
    fi
    d=${d%/*}
  done
  return 1
}

load_env() { set -a; [ -f "$1/.eduvia-env" ] && . "$1/.eduvia-env"; set +a; }

# Where a server starts: the env's ports (eduvia-env slots), else the main checkout's.
# Histoire: 6100 + slot, 6006 in the main checkout.
port_of() {
  (
    load_env "$1"
    slot=${EDUVIA_ENV_SLOT:-0}
    case $2 in
      front) echo "${EDUVIA_FRONT_PORT:-3100}" ;;
      back) echo "${EDUVIA_BACK_PORT:-3000}" ;;
      histoire) echo $(( slot ? 6100 + slot : 6006 )) ;;
    esac
  )
}

state_of() { printf '%s/%s-%s' "$state_dir" "$(printf %s "$1" | md5sum | cut -c1-12)" "$2"; }

ppid_of() {
  local key value
  while read -r key value _; do
    [ "$key" = PPid: ] && { printf %s "$value"; return 0; }
  done < "/proc/$1/status"
  return 1
}

# Listening processes whose folder is inside the checkout; one per server (a puma worker
# shares its master's sockets, so only the topmost owner is kept).
listeners() {
  local root=$1 pid port addr pp cwd chain up cmd
  local -A ports addrs
  while read -r pid port addr; do
    ports[$pid]+="${ports[$pid]:+,}$port"
    addrs[$pid]+="${addrs[$pid]:+,}$addr"
  done < <(ss -Hltnp 2>/dev/null | awk '{
    n = split($4, part, ":"); port = part[n]; addr = substr($4, 1, length($4) - length(port) - 1)
    rest = $0
    while (match(rest, /pid=[0-9]+/)) { print substr(rest, RSTART + 4, RLENGTH - 4), port, addr; rest = substr(rest, RSTART + RLENGTH) }
  }')
  for pid in "${!ports[@]}"; do
    pp=$(ppid_of "$pid" 2>/dev/null) || continue
    [ -n "${ports[$pp]:-}" ] && continue
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null) || continue
    case "$cwd/" in "$root"/*) ;; *) continue ;; esac
    chain=$pp up=$pp
    while [ "$up" -gt 1 ] && up=$(ppid_of "$up" 2>/dev/null); do chain+=",$up"; done
    cmd=$(tr '\0\t' '  ' < "/proc/$pid/cmdline" 2>/dev/null)
    printf 'L\t%s\t%s\t%s\t%s\t%s\t%s\n' "$pid" "${ports[$pid]}" "${addrs[$pid]}" "$cwd" "$chain" "$cmd"
  done
}

cmd_root() {
  local d
  for d; do checkout_of "$d" && break; done
  return 0
}

cmd_status() {
  local root=$1 s f action pid since
  [ -d "$root" ] || { echo "pas de checkout ici : $root" >&2; return 1; }
  printf 'R\t%s\n' "$root"
  [ -f "$root/.eduvia-env" ] && grep -E '^[A-Z_]+=' "$root/.eduvia-env" | sed 's/=/\t/; s/^/V\t/'
  for s in $SERVERS; do printf 'X\t%s\t%s\n' "$s" "$(port_of "$root" "$s")"; done
  for s in ss jq hc; do command -v "$s" >/dev/null || printf 'M\t%s\n' "$s"; done
  listeners "$root"
  for s in $SERVERS; do
    f=$(state_of "$root" "$s")
    if [ -f "$f.pending" ] && read -r action pid since < "$f.pending"; then
      if kill -0 "$pid" 2>/dev/null; then printf 'P\t%s\t%s\t%s\n' "$s" "$action" "$since"; else rm -f "$f.pending"; fi
    fi
    [ -s "$f.error" ] && printf 'E\t%s\t%s\n' "$s" "$(tr '\n\t' '  ' < "$f.error")"
  done
  [ -f "$root/backend/log/development.log" ] && printf 'F\tback\t%s\n' "$root/backend/log/development.log"
  [ -f "$root/frontend/log/development.log" ] && printf 'F\tfront\t%s\n' "$root/frontend/log/development.log"
  return 0
}

# --- ctl: one action, detached; the mod shows it as pending until it returns ---------

fail() { printf '%s\n' "$*" > "$f.error"; echo "  échec : $*"; exit 1; }
alive() { [ "$1" != - ] && kill -0 "$1" 2>/dev/null; }
gone() { ! alive "$1"; }
# Something of this checkout listens on the port (not another env's server on it).
listening() {
  local p
  for p in $(ss -Hltnp "sport = :$1" 2>/dev/null | grep -oP 'pid=\K\d+' | sort -u); do
    case "$(readlink "/proc/$p/cwd" 2>/dev/null)/" in "$root"/*) return 0 ;; esac
  done
  return 1
}
# Taken by another program. tools/dev-share's socat relays (Tailscale address → localhost)
# don't count: the server binds next to them.
taken() { ss -Hltnp "sport = :$1" 2>/dev/null | grep -v '"socat"' | grep -q .; }
term_field() { hc get "$1" --json 2>/dev/null | jq -r "$2"; }
term_live() { [ "$(term_field "$1" .state)" = live ]; }
not_live() { ! term_live "$1"; }
at_prompt() { [ "$(term_field "$1" '.foreground.pid == .pid')" = true ]; }
# within <half-seconds> <check> <args>
within() {
  local n=$1; shift
  until "$@"; do
    n=$((n - 1)); [ "$n" -le 0 ] && return 1
    sleep 0.5
  done
}

signal_stop() {
  alive "$pid" || return 0
  kill -TERM "$pid" 2>/dev/null
  within 40 gone "$pid" && return 0
  kill -KILL "$pid" 2>/dev/null
  within 10 gone "$pid" || fail "le processus $pid ne s’arrête pas"
}

stop_server() {
  case $how in
    managed)
      hc label "$term" eduvia.next=stop >/dev/null
      [ -n "$(term_field "$term" '.labels["eduvia.failed"] // ""')" ] || hc interrupt "$term" --timeout 5 >/dev/null
      within 60 not_live "$term" && return 0
      hc kill "$term" >/dev/null
      within 20 not_live "$term" || fail "le terminal $term ne s’arrête pas"
      ;;
    inplace)
      hc interrupt "$term" --timeout 5 >/dev/null
      within 60 gone "$pid" || signal_stop
      ;;
    external) signal_stop ;;
  esac
}

# Waits until the server listens on its port. Gives up if it crashed (managed), if the
# shell is back at its prompt (inplace), or after 5 minutes (migrations, a cold Vite).
wait_up() {
  local n=0
  until listening "$port"; do
    n=$((n + 1))
    [ "$n" -ge 600 ] && fail "rien n’écoute sur le port $port après 5 min"
    if [ "$how" = managed ]; then
      term_live "$term" || fail "$server s’est arrêté au démarrage"
      [ -n "$(term_field "$term" '.labels["eduvia.failed"] // ""')" ] && fail "$server s’est arrêté au démarrage (voir les logs)"
    elif [ "$how" = inplace ] && [ "$n" -ge 10 ] && at_prompt "$term"; then
      fail "$server s’est arrêté au démarrage (voir les logs)"
    fi
    sleep 0.5
  done
}

start_server() {
  if ! listening "$port" && taken "$port"; then
    fail "port $port déjà pris par un autre processus ($(ss -Hltnp "sport = :$port" | grep -v '"socat"' | grep -oP 'users:\(\("\K[^"]+' | head -1))"
  fi
  if [ "$how" = managed ] && term_live "$term"; then
    # It crashed and waits in its terminal: run it again there.
    hc label "$term" eduvia.failed= eduvia.next=restart >/dev/null
  else
    term=$(hc run --bg --json --no-parent --no-notify --rm --cwd "$root" \
      --label "eduvia.root=$root" --label "eduvia.server=$server" \
      -- "$self" serve managed "$root" "$server" | jq -r '.address // empty')
    [ -n "$term" ] || fail "hc run n’a pas démarré $server"
    how=managed
  fi
  wait_up
}

restart_server() {
  case $how in
    managed)
      if term_live "$term"; then
        local failed
        failed=$(term_field "$term" '.labels["eduvia.failed"] // ""')
        hc label "$term" eduvia.next=restart >/dev/null
        # A crashed one waits for the label; a running one stops first.
        [ -n "$failed" ] || hc interrupt "$term" --timeout 5 >/dev/null
        within 60 gone "$pid" || signal_stop
      fi
      start_or_wait
      ;;
    inplace)
      hc interrupt "$term" --timeout 5 >/dev/null
      within 60 gone "$pid" || signal_stop
      within 20 at_prompt "$term" || fail "le terminal $term n’est pas revenu au prompt"
      hc send "$term" "$(printf '%q ' "$self" serve inplace "$root" "$server")" >/dev/null \
        || fail "impossible d’écrire dans le terminal $term"
      wait_up
      ;;
    external) signal_stop; how=none; start_server ;;
    *) start_server ;;
  esac
}

# After a managed restart: the same terminal runs it again, unless it ended meanwhile.
start_or_wait() {
  if term_live "$term"; then wait_up; else how=none; start_server; fi
}

cmd_ctl() {
  action=$1 root=$2 server=$3 how=$4 term=$5 pid=$6
  mkdir -p "$state_dir"
  f=$(state_of "$root" "$server")
  # One action at a time per server.
  local other
  if [ -f "$f.pending" ] && read -r _ other _ < "$f.pending" && kill -0 "$other" 2>/dev/null; then exit 0; fi
  printf '%s %s %s\n' "$action" "$$" "$(date +%s)" > "$f.pending"
  trap 'rm -f "$f.pending"' EXIT
  rm -f "$f.error"
  exec >>"$state_dir/ctl.log" 2>&1
  echo "$(date '+%F %T') $action $server $root ($how $term $pid)"
  port=$(port_of "$root" "$server")
  case $action in
    start) start_server ;;
    stop) stop_server ;;
    restart) restart_server ;;
    *) fail "action inconnue : $action" ;;
  esac
  echo "  ok"
}

# --- serve: the server itself ---------------------------------------------------------

label() { [ -n "${HC_TERMINAL_ID:-}" ] && hc label "$HC_TERMINAL_ID" "$@" >/dev/null 2>&1; }
next_label() { [ -n "${HC_TERMINAL_ID:-}" ] && term_field "$HC_TERMINAL_ID" '.labels["eduvia.next"] // ""'; }
step() { printf '\033[2m▶ %s\033[0m\n' "$*"; "$@"; }

serve_once() {
  (
    case $server in
      front) cd frontend && step bun run dev ;;
      back) cd backend && step bin/rails db:migrate && step bin/rails server ;;
      histoire) cd frontend && step bun run story:dev --host 0.0.0.0 --port "$(port_of "$root" histoire)" ;;
      *) echo "serveur inconnu : $server" >&2; exit 2 ;;
    esac
  )
}

cmd_serve() {
  local mode=$1 rc
  root=$2 server=$3
  # Through the person's login shell once: the PATH their terminals have (rbenv, bun, node).
  if [ "$mode" = managed ] && [ -z "${EDUVIA_SERVERS_SHELL:-}" ]; then
    export EDUVIA_SERVERS_SHELL=1
    exec "${SHELL:-/bin/bash}" -lic 'exec "$0" "$@"' "$self" serve "$@"
  fi
  cd "$root" || exit 1
  # The checkout's .envrc as direnv loads it (ports, hosts, DB suffix, NODE_OPTIONS);
  # .eduvia-env again in case direnv is missing or the folder isn't allowed.
  command -v direnv >/dev/null && eval "$(direnv export bash 2>/dev/null)"
  load_env "$root"
  # Puma takes its binds from config/puma.rb and Nuxt prefers PORT to devServer.port:
  # an inherited PORT would override both (as tools/env/eduvia-env start does).
  unset PORT
  if [ "$mode" = inplace ]; then serve_once; exit; fi

  # Ctrl-C stops the server (its own process group gets it) and then this loop.
  trap 'stopped=1' INT TERM HUP
  while :; do
    label eduvia.next= eduvia.failed=
    stopped=0
    serve_once; rc=$?
    case $(next_label) in restart) continue ;; stop) exit 0 ;; esac
    case $rc in 0|129|130|143) exit 0 ;; esac
    [ "$stopped" = 1 ] && exit 0
    printf '\n\033[31m✖ %s s’est arrêté (code %s) : relance-le depuis Serveurs Eduvia.\033[0m\n' "$server" "$rc"
    label "eduvia.failed=$rc"
    while :; do
      sleep 1 & wait $!
      [ "$stopped" = 1 ] && exit 0
      case $(next_label) in restart) continue 2 ;; stop) exit 0 ;; esac
    done
  done
}

case ${1:-} in
  root) shift; cmd_root "$@" ;;
  status) shift; cmd_status "$@" ;;
  ctl) shift; cmd_ctl "$@" ;;
  serve) shift; cmd_serve "$@" ;;
  *) sed -n '2,20p' "$self" >&2; exit 2 ;;
esac
