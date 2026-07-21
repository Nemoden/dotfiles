#!/usr/bin/env bash
# PreToolUse(Bash) guard. Block committing paths marked nogit.
# Markers: 'nogit-' (dir/file prefix), '-nogit.' (suffix before ext), '.nogit' (dotfile/ext).
#
# Plan B: don't trust the command string. On any commit, ask git what is
# actually staged AND what is already tracked, then match markers against
# those real paths. Catches every route in (add -A, dir-add, quoted path,
# commit -a, or an already-leaked file being re-committed).
#
# Reads hook JSON on stdin, exits 2 with reason to deny.

# Anchor markers to path-segment boundaries so an incidental substring
# (e.g. this file, block-nogit-commit.sh) is not a false positive.
#   (^|/)nogit-   segment NAME starts with 'nogit-'
#   -nogit\.      segment stem ends with '-nogit' before its extension
#   (^|/)\.nogit  segment IS a .nogit dotfile / .nogit ext at segment start
MARKERS='(^|/)nogit-|-nogit\.|(^|/)\.nogit'

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)

[ -z "$cmd" ] && exit 0

# Only guard commits. add/staging is harmless until it reaches a commit,
# and checking at commit time is the single point of no return.
case "$cmd" in
  *commit*) : ;;
  *) exit 0 ;;
esac

# The commit may target the dotfiles repo (via the `dot` wrapper, which is
# `git --git-dir=$HOME/.dot --work-tree=$HOME`) or an ordinary repo in cwd.
# Reuse the same --git-dir/--work-tree the command uses so we inspect the
# SAME repo. If absent, git falls back to the ambient repo (cwd), which is
# correct for a normal `git commit`.
gitdir=$(printf '%s' "$cmd" | grep -oE -- '--git-dir[= ][^ ]+' | head -1 | sed -E 's/^--git-dir[= ]//')
worktree=$(printf '%s' "$cmd" | grep -oE -- '--work-tree[= ][^ ]+' | head -1 | sed -E 's/^--work-tree[= ]//')

# expand a leading ~ or $HOME so git gets a real path
expand() { printf '%s' "$1" | sed -E "s|^~|$HOME|; s|^\\\$HOME|$HOME|"; }
gitdir=$(expand "$gitdir")
worktree=$(expand "$worktree")

gitargs=()
[ -n "$gitdir" ]   && gitargs+=("--git-dir=$gitdir")
[ -n "$worktree" ] && gitargs+=("--work-tree=$worktree")

# 1) paths staged for this commit
staged=$(git "${gitargs[@]}" diff --cached --name-only 2>/dev/null)
# 2) paths already tracked (guards re-committing an existing leak, and
#    catches `commit -a` since -a can only touch already-tracked files)
tracked=$(git "${gitargs[@]}" ls-files 2>/dev/null)

hits=$(printf '%s\n%s\n' "$staged" "$tracked" | sort -u | grep -E "$MARKERS")

if [ -n "$hits" ]; then
  echo "BLOCKED: commit involves 'nogit' path(s) (matched nogit-/-nogit./.nogit):" >&2
  printf '  %s\n' $hits >&2
  echo "These are intentionally kept out of git. If a listed path is already tracked, untrack it first: git rm --cached <path>. If you really mean to commit it, run the git/dot command yourself in a '! ...' prompt." >&2
  exit 2
fi

exit 0
