#!/usr/bin/env bash
# PreToolUse(Bash) guard. Block staging/committing paths marked nogit.
# Markers: 'nogit-' (dir/file prefix), '-nogit.' (suffix before ext), '.nogit' (dotfile/ext).
# Reads hook JSON on stdin, exits 2 with reason to deny.

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)

[ -z "$cmd" ] && exit 0

# only care about staging/committing verbs (git or dot wrapper)
case "$cmd" in
  *" add "*|*" add"|*commit*) : ;;
  *) exit 0 ;;
esac

# strip quoted strings (commit messages) so a 'nogit' word in -m "..."
# doesn't false-positive; we only want markers in bare path args.
stripped=$(printf '%s' "$cmd" | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")

# match nogit markers in the remaining (unquoted) tokens
if printf '%s' "$stripped" | grep -Eq 'nogit-|-nogit\.|\.nogit'; then
  echo "BLOCKED: command stages/commits a 'nogit' path (matched nogit-/-nogit./.nogit). These are intentionally kept out of git. If you really mean it, run the git/dot command yourself in a '! ...' prompt." >&2
  exit 2
fi

exit 0
