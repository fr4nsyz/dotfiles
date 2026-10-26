#!/bin/zsh
# AeroSpace -> sketchybar event dispatcher.
#
# ONE long-lived `aerospace subscribe` process streams events into a fifo.
# The loop paints sketchybar straight from event payloads, so switching the
# focused pip costs a single ~22ms sketchybar call and ZERO aerospace spawns.
# Occupied-set + fullscreen truth is reconciled by ONE async `aerospace eval`
# per event burst (~120ms, off the hot path) and folded in by the same painter.
# Bursts are drained (30ms) so one user action = 1 paint + 1 reconcile.
# An idle tick re-reconciles every 15s to catch windows closed in the
# background (aerospace emits no window-closed event).
#
# Launched from .aerospace.toml after-startup-command.
# Run with --paint-once to repaint current state (e.g. after sketchybar reload).
# zsh is required: the loop needs fractional `read -t` timeouts (bash 3.2 lacks them).

source "$HOME/.config/sketchybar/plugins/lib.sh"

WORKSPACES=(1-uni 2-work 3-resume 4-prep 5-utils 6-bridge 7-oss 8-proj 9-proj-2 10-comms)
EVENTS=(focused-workspace-changed focus-changed focused-monitor-changed window-detected binding-triggered)
LOCKFILE=/tmp/sketchybar-events.pid
OCC_CACHE=/tmp/sketchybar-occupied   # snapshot of last reconcile, for debugging/other scripts
RECON=/tmp/sketchybar-reconcile
FIFO=/tmp/sketchybar-aerospace.fifo.$$

BURST_DRAIN=0.03   # window for batching the events of one user action
POLL=0.1           # reconcile-result poll while a query is in flight
IDLE_TICK=2        # read timeout when idle
IDLE_RECON=15      # periodic truth refresh (silent background window closes)
STUCK=10           # give up on a hung reconcile after this many seconds

AERO=$(whence -p aerospace); [[ -x $AERO ]] || AERO=/opt/homebrew/bin/aerospace
SBAR=$(whence -p sketchybar); [[ -x $SBAR ]] || SBAR=/opt/homebrew/bin/sketchybar
[[ -x $AERO && -x $SBAR ]] || exit 1

QUERY='list-windows --focused --format "%{window-is-fullscreen}"; echo -- __SEP__; list-workspaces --monitor all --empty no; echo -- __FOC__; list-workspaces --focused'

FOCUSED=''
OCC=' '
FS=false
RFS=''
DIRTY=0
PENDING=0
FIRED_AT=0
SUBPID=''
typeset -A RCLS   # rendered class per pip: f=focused o=occupied e=empty
typeset -F SECONDS
LAST_RECON=0

dbg() {
  [[ -n $SB_DEBUG ]] && print -r -- "$(perl -MTime::HiRes=time -e 'printf "%.0f", time*1000') $*" >> /tmp/sketchybar-events.debug
  return 0
}

# JSON "key":"value" extractor (no jq spawn)
field() {
  local v=${1#*\"$2\":\"}
  print -r -- ${v%%\"*}
}

occ_has() { [[ $OCC == *" $1 "* ]] }

handle() { # one JSON event line -> in-memory state, zero spawns
  case $1 in
    *'"_event":"focused-workspace-changed"'*|*'"_event":"focus-changed"'*|*'"_event":"focused-monitor-changed"'*)
      FOCUSED=$(field "$1" workspace) ;;
    *'"_event":"window-detected"'*)
      local ws=$(field "$1" workspace)
      occ_has $ws || OCC="$OCC$ws " ;;
  esac
}

paint() { # sketchybar call only for items whose class changed since last paint
  local -a args=()
  local ws cls
  for ws in $WORKSPACES; do
    if [[ $ws == $FOCUSED ]]; then cls=f
    elif occ_has $ws; then cls=o
    else cls=e; fi
    [[ ${RCLS[$ws]} == $cls ]] && continue
    RCLS[$ws]=$cls
    case $cls in
      f) args+=(--set space.$ws label.color=$PIP_FG background.drawing=on \
           background.color=0x40a98bff background.border_width=1 background.border_color=$PIP_ACCENT) ;;
      o) args+=(--set space.$ws label.color=$PIP_ICON background.drawing=off) ;;
      e) args+=(--set space.$ws label.color=$PIP_DIM background.drawing=off) ;;
    esac
  done
  local fs=off; [[ $FS == true ]] && fs=on
  if [[ $RFS != $fs ]]; then
    RFS=$fs
    if [[ $fs == on ]]; then
      args+=(--set fullscreen drawing=on label.color=$PIP_AMBER \
        background.drawing=on background.color=0x40e6a94d \
        background.border_width=1 background.border_color=$PIP_AMBER)
    else
      args+=(--set fullscreen drawing=off)
    fi
  fi
  (( ${#args} )) && {
    dbg "paint ${#args} props"
    $SBAR "${args[@]}" 2>/dev/null || { RCLS=(); RFS=''; }  # bar restarted: force full repaint next time
  }
  return 0
}

parse_query() { # stdin = reconcile file -> q_fs q_occ q_foc q_cache
                # rc: 0=complete, 1=not ready yet (no __DONE__ marker), 2=garbage
  local line sec=0 seen=0 done=0
  q_fs=false q_occ=' ' q_foc='' q_cache=''
  while IFS= read -r line; do
    [[ $line == __DONE__ ]] && { done=1; break; }
    case $line in
      __SEP__) sec=1; seen=1 ;;
      __FOC__) sec=2 ;;
      '') ;;
      *) case $sec in
           0) q_fs=$line ;;
           1) q_occ="$q_occ$line "; q_cache+="$line
" ;;
           2) q_foc=$line ;;
         esac ;;
    esac
  done
  (( done )) || return 1
  (( seen )) || return 2
  [[ $q_fs == true || $q_fs == false ]] || q_fs=false
  return 0
}

fire_recon() { # async truth query, off the hot path
  PENDING=1
  FIRED_AT=$SECONDS
  ( $AERO eval "$QUERY" > $RECON 2>/dev/null; print -r -- __DONE__ >> $RECON ) &
}

apply_recon() { # rc: 0=applied, 1=not ready, 2=garbage
  [[ -r $RECON ]] || return 1
  parse_query < $RECON
  local rc=$?
  (( rc == 1 )) && return 1
  PENDING=0
  if (( rc == 2 )); then
    LAST_RECON=$SECONDS   # back off; retry on next event or idle tick
    dbg "recon garbage"
    return 2
  fi
  FS=$q_fs
  OCC=$q_occ
  [[ -n $q_cache ]] && printf '%s' "$q_cache" > $OCC_CACHE
  LAST_RECON=$SECONDS
  dbg "recon fs=$FS occ=[$OCC] foc=[$q_foc]"
  return 0
}

start_subscribe() {
  rm -f $FIFO
  mkfifo $FIFO
  $AERO subscribe "${EVENTS[@]}" > $FIFO 2>/dev/null &
  SUBPID=$!
  exec 3< $FIFO
}

# --- one-shot mode (sketchybar reload) --------------------------------------
if [[ ${1:-} == --paint-once ]]; then
  rm -f $RECON
  $AERO eval "$QUERY" > $RECON 2>/dev/null
  print -r -- __DONE__ >> $RECON
  apply_recon
  rc=$?
  if (( rc == 0 )); then
    FOCUSED=$q_foc
    paint
  fi
  rm -f $RECON
  exit $(( rc == 2 ))
fi

# --- daemon mode ------------------------------------------------------------
if [[ -f $LOCKFILE ]] && kill -0 $(< $LOCKFILE) 2>/dev/null; then
  exit 0
fi
print -r -- $$ > $LOCKFILE

cleanup() {
  [[ -n $SUBPID ]] && kill $SUBPID 2>/dev/null
  rm -f $FIFO $LOCKFILE $RECON
}
trap 'cleanup; exit 0' TERM INT HUP
trap cleanup EXIT

start_subscribe

# initial truth; subscribe's initial-state events are buffered behind this query
rm -f $RECON
$AERO eval "$QUERY" > $RECON 2>/dev/null
print -r -- __DONE__ >> $RECON
if apply_recon; then
  FOCUSED=$q_foc
fi
rm -f $RECON
paint

n=0
while :; do
  to=$IDLE_TICK
  [[ $PENDING == 1 ]] && to=$POLL
  if IFS= read -r -t $to -u 3 line; then
    dbg "recv $line"
    handle "$line"
    while IFS= read -r -t $BURST_DRAIN -u 3 line; do
      dbg "recv $line"
      handle "$line"
      (( ++n % 25 == 0 )) && paint   # anti-starvation under event floods
    done
    paint
    DIRTY=1
  elif ! kill -0 $SUBPID 2>/dev/null; then
    dbg "subscribe died, respawning"
    exec 3<&-
    sleep 1
    start_subscribe
    continue
  else
    (( SECONDS - LAST_RECON >= IDLE_RECON )) && DIRTY=1   # idle truth refresh
  fi
  if [[ $PENDING == 1 ]]; then
    apply_recon
    case $? in
      0) paint ;;
      2) DIRTY=0 ;;
      1) (( SECONDS - FIRED_AT > STUCK )) && { PENDING=0; DIRTY=1; } ;;
    esac
  fi
  if [[ $DIRTY == 1 && $PENDING == 0 ]]; then
    fire_recon
    DIRTY=0
  fi
done
