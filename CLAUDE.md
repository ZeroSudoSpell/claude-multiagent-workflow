# CLAUDE.md

<!--
This file is loaded by the main session AND by every subagent, so it is where
the planner, implementers and reviewer learn how your project works.
Fill in the "Project" sections. Leave the "Workflow" section as is unless you
are changing how the team works.
-->

## Project

<One paragraph: what this codebase is and who uses it.>

### Commands

Agents run these exact commands. Keep them accurate. Implementers run them
from inside their own worktree, so each command must test the code in the
directory it runs from, not an installed copy. For example, with a Python
`src/` layout and an editable install, use `PYTHONPATH=src python3 -m pytest`.

| Purpose | Command |
|---|---|
| Install deps | `<e.g. npm ci / pip install -e '.[dev]'>` |
| Test (all) | `<e.g. npm test / pytest>` |
| Test (one file) | `<e.g. npx vitest run path / pytest path>` |
| Lint | `<e.g. npm run lint / ruff check .>` |
| Format | `<e.g. npm run format / ruff format .>` |
| Type check | `<e.g. npx tsc --noEmit / mypy .>` |

### Conventions

- <Layout: where source, tests and docs live.>
- <Style rules a linter doesn't enforce.>
- <Anything an agent keeps getting wrong. Add it here.>

## Workflow

This repo uses a multi-agent workflow. See `docs/workflow.md` for the
details.

- **Agents:** `planner` (read-only, plans), `implementer` (builds one task in
  its own git worktree), `reviewer` (read-only, reviews against
  `.claude/review/checklist.md`).
- **Skills:** `/feature` (plan → parallel build → review → integrate),
  `/delegate` (one task in the background), `/review` (review a branch or
  diff), `/tidy` (clean up worktrees).
- **When to delegate:** if a change touches more than ~3 files, or has parts
  that can be built independently, use `/feature` rather than editing
  directly. For a single self-contained fix you want done off to the side,
  use `/delegate`.
- **Branches:** features are built on `feature/<slug>`. Implementer worktrees
  branch from that branch's latest commit, so commit before delegating.
- **Never push or open PRs** unless the human asks. Merging task branches
  into a local feature branch is fine; anything that leaves this machine is
  the human's call.
- **Destructive git** (force push, `reset --hard`, `clean -f`, `branch -D`,
  pushes to protected branches) is blocked by `.claude/hooks/guard-git.sh`.
  Don't work around it; ask the human.
