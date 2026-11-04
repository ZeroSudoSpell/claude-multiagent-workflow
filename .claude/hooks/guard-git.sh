#!/usr/bin/env bash
# PreToolUse hook for the Bash tool.
#
# Blocks git commands that are hard to undo or that publish work, so that no
# agent (main session or subagent) can do them on its own. Humans can still
# run them in their own terminal.
#
# Input: the hook event as JSON on stdin. Exit 0 to allow, exit 2 to block;
# on exit 2, stderr is shown to Claude as the reason.
set -euo pipefail

input="$(cat)"

# Pull out tool_input.command. Prefer jq, then python3; if neither is
# installed, fall back to matching against the raw JSON, which can only
# over-block, never under-block.
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
elif command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')"
else
  cmd="$input"
fi

[[ -z "$cmd" ]] && exit 0

block() {
  echo "Blocked by .claude/hooks/guard-git.sh: $1" >&2
  echo "If this is really needed, tell the human the exact command so they can run it themselves." >&2
  exit 2
}

# Only look at commands that invoke git at all.
grep -Eq '(^|[^[:alnum:]_-])git([[:space:]]|$)' <<<"$cmd" || exit 0

protected='(main|master|trunk|develop|release[/[:alnum:]._-]*)'

if grep -Eq 'git[[:space:]](.*[[:space:]])?push([[:space:]]|$)' <<<"$cmd"; then
  # Force pushes. --force-with-lease is allowed only to non-protected
  # branches (checked below), plain --force / -f / +refspec never.
  if grep -Eq '(^|[[:space:]])(--force|-f)([[:space:]]|$)|[[:space:]]\+[^[:space:]]' <<<"$cmd"; then
    block "force push"
  fi
  if grep -Eq "([[:space:]]|:)${protected}([[:space:]]|$)" <<<"$cmd"; then
    block "push to a protected branch"
  fi
  if grep -Eq '(^|[[:space:]])--(mirror|all|delete)([[:space:]]|$)|[[:space:]]:[^[:space:]]' <<<"$cmd"; then
    block "push that deletes or mirrors refs"
  fi
fi

if grep -Eq 'git[[:space:]]+reset[[:space:]]+(.*[[:space:]])?--hard' <<<"$cmd"; then
  block "git reset --hard discards work"
fi

if grep -Eq 'git[[:space:]]+clean[[:space:]]+(.*[[:space:]])?-[[:alpha:]]*f' <<<"$cmd"; then
  block "git clean -f deletes untracked files"
fi

if grep -Eq 'git[[:space:]]+branch[[:space:]]+(.*[[:space:]])?(-D|--delete[[:space:]]+--force|--force[[:space:]]+--delete)' <<<"$cmd"; then
  block "git branch -D deletes unmerged work (use -d)"
fi

if grep -Eq 'git[[:space:]]+worktree[[:space:]]+remove[[:space:]]+(.*[[:space:]])?(--force|-f)([[:space:]]|$)' <<<"$cmd"; then
  block "git worktree remove --force discards uncommitted changes"
fi

if grep -Eq 'git[[:space:]]+(checkout|restore)[[:space:]]+(.*[[:space:]])?(--[[:space:]]+)?\.([[:space:]]|$)' <<<"$cmd"; then
  block "discarding all working-tree changes"
fi

exit 0
