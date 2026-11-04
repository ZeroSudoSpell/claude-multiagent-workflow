#!/usr/bin/env bash
# Installs the template into throwaway repos and checks the result.
# Run: bash tests/test_install.sh
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

die() { echo "FAIL: $*" >&2; exit 1; }

# 1. Fresh repo: everything is copied and the result validates.
fresh="$tmp/fresh"
git init -q "$fresh"
"$here/scripts/install.sh" "$fresh" >/dev/null
for f in .claude/agents/implementer.md .claude/skills/feature/SKILL.md \
         .claude/settings.json CLAUDE.md .worktreeinclude docs/workflow.md; do
  [[ -f "$fresh/$f" ]] || die "fresh install is missing $f"
done
[[ -x "$fresh/.claude/hooks/guard-git.sh" ]] || die "hook lost its executable bit"
grep -qxF ".claude/worktrees/" "$fresh/.gitignore" || die ".gitignore not updated"
python3 "$here/scripts/validate.py" "$fresh" >/dev/null || die "installed setup does not validate"

# 2. Re-running is a no-op: no duplicate .gitignore lines.
"$here/scripts/install.sh" "$fresh" >/dev/null
[[ "$(grep -cxF ".claude/worktrees/" "$fresh/.gitignore")" -eq 1 ]] || die "re-run duplicated .gitignore lines"

# 3. Existing files are never overwritten.
existing="$tmp/existing"
git init -q "$existing"
echo "# my project" > "$existing/CLAUDE.md"
mkdir -p "$existing/.claude"
echo '{"model": "opus"}' > "$existing/.claude/settings.json"
out="$("$here/scripts/install.sh" "$existing")"
[[ "$(cat "$existing/CLAUDE.md")" == "# my project" ]] || die "CLAUDE.md was overwritten"
[[ "$(cat "$existing/.claude/settings.json")" == '{"model": "opus"}' ]] || die "settings.json was overwritten"
grep -q "Skipped 2 file" <<<"$out" || die "skipped files not reported"

# 4. The validator catches a broken agent.
rm "$fresh/.claude/agents/reviewer.md"
if python3 "$here/scripts/validate.py" "$fresh" >/dev/null; then
  die "validator passed although /review forks into a missing agent"
fi

echo "install: all checks passed"
