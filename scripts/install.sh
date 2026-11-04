#!/usr/bin/env bash
# Copy this workflow's .claude/ setup into an existing repository without
# overwriting anything that's already there.
#
#   scripts/install.sh /path/to/your/repo
#
# Files that already exist in the target are skipped and listed at the end,
# so you can merge them by hand.
set -euo pipefail

src="$(cd "$(dirname "$0")/.." && pwd)"
dst="${1:-}"

if [[ -z "$dst" || ! -d "$dst" ]]; then
  echo "usage: $0 <target-repo-dir>" >&2
  exit 1
fi
dst="$(cd "$dst" && pwd)"
if [[ "$src" == "$dst" ]]; then
  echo "target is this template itself; nothing to do" >&2
  exit 1
fi
if ! git -C "$dst" rev-parse --git-dir >/dev/null 2>&1; then
  echo "warning: $dst is not a git repository; worktrees need git" >&2
fi

copied=()
skipped=()

copy() {
  # copy <relative-path-in-template> [<relative-path-in-target>]
  local from="$src/$1" to="$dst/${2:-$1}"
  if [[ -e "$to" ]]; then
    skipped+=("${2:-$1}")
    return
  fi
  mkdir -p "$(dirname "$to")"
  cp -p "$from" "$to"
  copied+=("${2:-$1}")
}

while IFS= read -r f; do
  copy "${f#"$src"/}"
done < <(find "$src/.claude/agents" "$src/.claude/skills" "$src/.claude/hooks" "$src/.claude/review" -type f | sort)

copy .claude/settings.json
copy .worktreeinclude
copy docs/workflow.md
copy CLAUDE.md

# .gitignore: append the lines that are missing.
added=0
for line in ".claude/worktrees/" ".claude/settings.local.json" "CLAUDE.local.md"; do
  if ! grep -qxF "$line" "$dst/.gitignore" 2>/dev/null; then
    [[ $added -eq 0 ]] && printf '\n# Claude Code multi-agent workflow\n' >> "$dst/.gitignore"
    echo "$line" >> "$dst/.gitignore"
    added=$((added + 1))
  fi
done

echo "Copied ${#copied[@]} file(s) into $dst"
for f in "${copied[@]}"; do echo "  + $f"; done
[[ $added -gt 0 ]] && echo "  + $added line(s) appended to .gitignore"

if [[ ${#skipped[@]} -gt 0 ]]; then
  echo
  echo "Skipped ${#skipped[@]} file(s) that already exist. Merge these by hand:"
  for f in "${skipped[@]}"; do echo "  = $f   (template: $src/$f)"; done
  for f in "${skipped[@]}"; do
    case "$f" in
      CLAUDE.md) echo "    -> append the '## Workflow' section from the template's CLAUDE.md to yours." ;;
      .claude/settings.json) echo "    -> merge 'permissions', 'worktree' and 'hooks' from the template's settings.json." ;;
    esac
  done
fi

echo
echo "Next: fill in the Commands table in CLAUDE.md, then try /review or /delegate."
