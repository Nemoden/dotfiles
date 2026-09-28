#!/usr/bin/env bash
# Every INTERVAL, read a session's context use; at THRESHOLD% or more send MSG.
# Usage: watch.sh --session-id ID --window TOKENS (--msg TEXT | --msg-file FILE)
#                 [--threshold 60] [--interval 1800] [--idle-wait 1200]
#                 [--log FILE] [--once] [--dry-run]
# Checks run on a fixed grid (start + k*INTERVAL), so a reporter can align to it.
# Pane and transcript are looked up again each check from ~/.claude/sessions,
# so a session resumed in another pane is still followed.
set -u
unset TMUX
HERE="$(cd "$(dirname "$0")" && pwd)"

SID='' WINDOW='' MSG='' THRESHOLD=60 INTERVAL=1800 IDLE_WAIT=1200
LOG="${TMPDIR:-/tmp}/drive-session-watch.log" ONCE=0 DRY=''
while [[ $# -gt 0 ]]; do
  case $1 in
    --session-id) SID=$2; shift 2 ;;
    --window) WINDOW=$2; shift 2 ;;
    --msg) MSG=$2; shift 2 ;;
    --msg-file) MSG=$(<"$2"); shift 2 ;;
    --threshold) THRESHOLD=$2; shift 2 ;;
    --interval) INTERVAL=$2; shift 2 ;;
    --idle-wait) IDLE_WAIT=$2; shift 2 ;;
    --log) LOG=$2; shift 2 ;;
    --once) ONCE=1; shift ;;
    --dry-run) DRY=--dry-run; shift ;;
    *) echo "unknown arg $1" >&2; exit 64 ;;
  esac
done
[[ -n $SID && -n $WINDOW && -n $MSG ]] || { sed -n '2,8p' "$0" >&2; exit 64; }

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

# Prints: PANE TOKENS TRANSCRIPT NLIVE. Fails when session not live.
# One id can be live in two processes (a resumed copy); newest registry update wins.
lookup() {
  python3 "$HERE/find-sessions.py" --json "$SID" | python3 -c '
import json, sys
live = [s for s in json.load(sys.stdin) if s["session_id"] == sys.argv[1]]
if not live:
    sys.exit(1)
s = max(live, key=lambda s: s["updated_at"])
print(s["pane"] or "-", s.get("context_tokens") or "?", s["transcript"] or "-", len(live))
' "$SID"
}

boundaries() { grep -c '"compact_boundary"' "$1" 2>/dev/null || echo 0; }

# After a /compact send, wait up to 15 min for a new compact_boundary row.
confirm_compact() {
  local tr=$1 before=$2 i
  for i in $(seq 90); do
    sleep 10
    if (( $(boundaries "$tr") > before )); then
      log "compact confirmed: $(grep '"compact_boundary"' "$tr" | tail -1 | python3 -c '
import json, sys
m = json.loads(sys.stdin.read())["compactMetadata"]
print(m.get("preTokens"), "->", m.get("postTokens"), "tokens")')"
      return
    fi
  done
  log "WARNING no compact_boundary 15 min after send; check pane"
}

check_once() {
  local pane tokens tr nlive pct rc err before
  read -r pane tokens tr nlive < <(lookup) || { log "session $SID not live, exiting"; exit 2; }
  (( nlive > 1 )) && log "note: id live in $nlive processes, using newest ($pane)"
  [[ $tokens == '?' ]] && { log "pane=$pane cannot read context from transcript"; return; }
  pct=$(( tokens * 100 / WINDOW ))
  log "pane=$pane context ${pct}% ($tokens tokens), threshold ${THRESHOLD}%"
  (( pct < THRESHOLD )) && return
  before=$(boundaries "$tr")
  err=$("$HERE/send.sh" $DRY --wait "$IDLE_WAIT" "$pane" "$MSG" 2>&1); rc=$?
  case $rc in
    0) log "sent: $MSG ${err:+($err)}"
       [[ -z $DRY && $MSG == /compact* ]] && confirm_compact "$tr" "$before" ;;
    3) log "skip this check, $err after ${IDLE_WAIT}s" ;;
    *) log "send failed rc=$rc: $err" ;;
  esac
}

log "start session=$SID window=$WINDOW threshold=${THRESHOLD}% interval=${INTERVAL}s dry=${DRY:-no}"
start=$(date +%s) k=0
while true; do
  check_once
  (( ONCE )) && exit 0
  now=$(date +%s)
  while (( start + k * INTERVAL <= now )); do k=$((k+1)); done
  sleep $(( start + k * INTERVAL - now ))
done
