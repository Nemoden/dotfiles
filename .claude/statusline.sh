#!/bin/bash
# Read JSON input from stdin
input=$(cat)

# ANSI colors
RST='\033[0m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
MAGENTA='\033[35m'
BOLD='\033[1m'
WHITE='\033[37m'
ORANGE='\033[38;5;208m'
BRIGHT_RED='\033[91m'
BRIGHT_MAGENTA='\033[95m'

# Extract values
MODEL=$(echo "$input" | jq -r '
  if .model | type == "object" then .model.display_name // .model.id // "?"
  else .model // "?"
  end
')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
# Claude Code flickers xhigh→high; use settings as floor (JSON wins if higher)
effort_rank() {
    case "$1" in
        low) echo 1;; medium) echo 2;; high) echo 3;; xhigh) echo 4;; max) echo 5;; *) echo 0;;
    esac
}
if [ -n "$EFFORT" ]; then
    SETTINGS_EFFORT=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)
    [ "$(effort_rank "$SETTINGS_EFFORT")" -gt "$(effort_rank "$EFFORT")" ] && EFFORT="$SETTINGS_EFFORT"
fi
CWD=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // "?"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
CTX_USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Shorten cwd: show last 2 path components
SHORT_CWD=$(echo "$CWD" | rev | cut -d'/' -f1-2 | rev)

# Git branch + dirty count + ahead/behind upstream
GIT_BRANCH=""
if git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        GIT_BRANCH=" ⎇ $BRANCH"
        DIRTY=$(git -C "$CWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        [ "$DIRTY" -gt 0 ] && GIT_BRANCH+=" ${YELLOW}*$DIRTY${RST}${MAGENTA}"
        read -r BEHIND AHEAD <<< "$(git -C "$CWD" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)"
        [ -n "$AHEAD" ] && [ "$AHEAD" -gt 0 ] && GIT_BRANCH+=" ${GREEN}↑$AHEAD${RST}${MAGENTA}"
        [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ] && GIT_BRANCH+=" ${RED}↓$BEHIND${RST}${MAGENTA}"
    fi
fi

# Round cost to 2 decimal places
COST_FMT=$(printf '$%.2f' "$COST")

# Effort display with intensity color
EFFORT_DISPLAY=""
if [ -n "$EFFORT" ]; then
    case "$EFFORT" in
        low)    EFFORT_CLR="$DIM$WHITE"; EFFORT_LBL="low" ;;
        medium) EFFORT_CLR="$GREEN"; EFFORT_LBL="med" ;;
        high)   EFFORT_CLR="$YELLOW"; EFFORT_LBL="high" ;;
        xhigh)  EFFORT_CLR="$BRIGHT_MAGENTA$BOLD"; EFFORT_LBL="xhigh" ;;
        max)    EFFORT_CLR="$BRIGHT_RED$BOLD"; EFFORT_LBL="MAX" ;;
        *)      EFFORT_CLR="$WHITE"; EFFORT_LBL="$EFFORT" ;;
    esac
    EFFORT_DISPLAY=" ${EFFORT_CLR}($EFFORT_LBL)${RST}"
fi

# Context bar (10 chars wide) with color based on usage
CTX_DISPLAY=""
if [ -n "$CTX_USED_PCT" ] && [ -n "$CTX_SIZE" ]; then
    PCT=$(printf '%.0f' "$CTX_USED_PCT")
    SIZE_K=$(echo "$CTX_SIZE" | awk '{printf "%.0fk", $1/1000}')

    # Bar color by usage
    if [ "$PCT" -lt 30 ]; then
        BAR_CLR="$GREEN"
    elif [ "$PCT" -lt 50 ]; then
        BAR_CLR="$YELLOW"
    elif [ "$PCT" -lt 65 ]; then
        BAR_CLR="$ORANGE"
    else
        BAR_CLR="$RED"
    fi

    BAR_WIDTH=10
    FILLED=$(( PCT * BAR_WIDTH / 100 )); [ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
    BAR=""
    for ((i=0; i<FILLED; i++)); do BAR+="━"; done
    EMPTY=""
    for ((i=FILLED; i<BAR_WIDTH; i++)); do EMPTY+="╌"; done
    CTX_DISPLAY="[${BAR_CLR}${BAR}${RST}${DIM}${EMPTY}${RST}] ${BAR_CLR}${PCT}%${RST}${DIM}/$SIZE_K${RST} "
fi

# last-response time from Stop hook tmpfile; omit segment if absent
H=$(printf %s "$CWD" | { md5 -q 2>/dev/null || md5sum 2>/dev/null; } | head -c 8)
TS_DISPLAY=""
[ -n "$H" ] && [ -f "/tmp/claude-stop-$H" ] && TS_DISPLAY="${DIM} | $(cat "/tmp/claude-stop-$H")${RST}"

# Usage line: 5h/7d utilization + reset countdown from OAuth usage API.
# Whole line omitted when no keychain credentials or API unreachable.
usage_color() {
    if [ "$1" -lt 50 ]; then echo "$GREEN"
    elif [ "$1" -lt 80 ]; then echo "$YELLOW"
    else echo "$RED"; fi
}

USAGE_LINE=""
USAGE_CACHE="$HOME/.cache/statusline-usage.json"
CACHE_MAX_AGE=180

CACHE_AGE=$CACHE_MAX_AGE
[ -f "$USAGE_CACHE" ] && CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0) ))

if [ "$CACHE_AGE" -ge "$CACHE_MAX_AGE" ]; then
    CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    # security prints hex when value has non-ASCII; decode if needed
    case "$CREDS" in
        '{'*) ;;
        *) CREDS=$(printf %s "$CREDS" | xxd -r -p 2>/dev/null) ;;
    esac
    TOKEN=$(printf %s "$CREDS" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    if [ -n "$TOKEN" ]; then
        mkdir -p "$(dirname "$USAGE_CACHE")"
        FRESH=$(curl -sf -m 5 \
            -H "Authorization: Bearer $TOKEN" \
            -H "anthropic-beta: oauth-2025-04-20" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if printf %s "$FRESH" | jq -e '.five_hour' >/dev/null 2>&1; then
            printf %s "$FRESH" > "$USAGE_CACHE"
        else
            # fetch failed: touch cache to back off, keep stale data if any
            [ -f "$USAGE_CACHE" ] && touch "$USAGE_CACHE"
        fi
    fi
fi

if [ -f "$USAGE_CACHE" ]; then
    read -r PCT_5H PCT_7D RESET_EPOCH <<< "$(jq -r '
        [
          (.five_hour.utilization // "-"),
          (.seven_day.utilization // "-"),
          ((.five_hour.resets_at // "") | sub("\\.[0-9]+"; "") | (try fromdateiso8601 catch "-"))
        ] | @tsv' "$USAGE_CACHE" 2>/dev/null)"
    SEGS=""
    if [ "$PCT_5H" != "-" ] && [ -n "$PCT_5H" ]; then
        P=$(printf '%.0f' "$PCT_5H")
        SEGS="${DIM}5h${RST} $(usage_color "$P")${P}%${RST}"
    fi
    if [ "$PCT_7D" != "-" ] && [ -n "$PCT_7D" ]; then
        P=$(printf '%.0f' "$PCT_7D")
        SEGS="${SEGS:+$SEGS ${DIM}|${RST} }${DIM}7d${RST} $(usage_color "$P")${P}%${RST}"
    fi
    if [ "$RESET_EPOCH" != "-" ] && [ -n "$RESET_EPOCH" ]; then
        LEFT=$(( RESET_EPOCH - $(date +%s) ))
        if [ "$LEFT" -gt 0 ]; then
            SEGS="${SEGS:+$SEGS ${DIM}|${RST} }${DIM}Reset:${RST} ${GREEN}$(( LEFT / 3600 ))h $(( LEFT % 3600 / 60 ))m${RST}"
        fi
    fi
    [ -n "$SEGS" ] && USAGE_LINE="$SEGS"
fi

echo -e "${BOLD}$MODEL${RST}$EFFORT_DISPLAY | ${CTX_DISPLAY}${CTX_DISPLAY:+| }${GREEN}$COST_FMT${RST}${TS_DISPLAY}"
echo -e "${CYAN}📁 $SHORT_CWD${MAGENTA}$GIT_BRANCH${RST}"
if [ -n "$USAGE_LINE" ]; then echo -e "$USAGE_LINE"; fi
exit 0
