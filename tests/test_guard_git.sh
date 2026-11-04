#!/usr/bin/env bash
# Table-driven tests for .claude/hooks/guard-git.sh.
# Run: bash tests/test_guard_git.sh
set -uo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
hook="$here/.claude/hooks/guard-git.sh"
fail=0
pass=0

# Feed a Bash tool call to the hook; print allow, block, or error.
verdict() {
  local json rc
  json="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1")"
  printf '%s' "$json" | "$hook" >/dev/null 2>&1
  rc=$?
  case $rc in 0) echo allow ;; 2) echo block ;; *) echo "error($rc)" ;; esac
}

expect() {
  local want="$1" cmd="$2" got
  got="$(verdict "$cmd")"
  if [[ "$got" == "$want" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected $want, got $got: $cmd"
  fi
}

# Allowed
expect allow "git status"
expect allow "git diff main...feature/x"
expect allow "git log --oneline -5"
expect allow "git commit -m 'T1: add parser'"
expect allow "git merge --no-ff feature/T1-parser"
expect allow "git checkout -b feature/login"
expect allow "git checkout main"
expect allow "git push origin feature/login"
expect allow "git push -u origin feature/main-menu"
expect allow "git push --force-with-lease origin feature/login"
expect allow "git branch -d worktree-agent-abc"
expect allow "git worktree remove .claude/worktrees/agent-abc"
expect allow "git clean -n"
expect allow "git reset --soft HEAD~1"
expect allow "ls -la && echo push --force"
expect allow "npm test"
expect allow "git -C ../other status"

# Blocked
expect block "git push --force"
expect block "git push -f origin feature/x"
expect block "git push origin +feature/x"
expect block "git push origin main"
expect block "git push origin HEAD:main"
expect block "git push -u origin master"
expect block "git push --force-with-lease origin main"
expect block "git push origin release/1.2"
expect block "git push origin --delete feature/x"
expect block "git push origin :feature/x"
expect block "git push --mirror"
expect block "git -C sub push origin main"
expect block "cd repo && git push origin main"
expect block "git reset --hard HEAD~1"
expect block "git reset --hard"
expect block "git clean -fd"
expect block "git clean -xdf"
expect block "git branch -D feature/x"
expect block "git worktree remove --force .claude/worktrees/x"
expect block "git checkout -- ."
expect block "git restore ."

echo "guard-git: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
