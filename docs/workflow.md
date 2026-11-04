# The workflow in detail

This page is the reference for how the agents and skills fit together. The
[README](../README.md) has the overview.

## Roles

| Role | Who | Can edit? | Model | Lives in |
|---|---|---|---|---|
| Orchestrator | your main Claude Code session, following a skill | yes, but only merges | your session's model | `.claude/skills/feature/` |
| Planner | `planner` subagent | no (Read/Grep/Glob only) | `opus` | `.claude/agents/planner.md` |
| Implementer | `implementer` subagent, one per task | yes, in its own worktree | `sonnet` | `.claude/agents/implementer.md` |
| Reviewer | `reviewer` subagent | no (edit tools disallowed) | `opus` | `.claude/agents/reviewer.md` |
| Human | you | yes | — | — |

Each subagent starts with a fresh context window that holds `CLAUDE.md`, its
own instructions and the prompt the orchestrator wrote. It knows nothing else
about the conversation. That's the point: the reviewer can't be talked into
approving by the reasoning that produced the code, and the orchestrator's
context only fills up with reports, not file contents.

## The contracts

Agents talk to each other through fixed Markdown formats, defined in each
agent file:

1. **Plan** (planner → orchestrator → human): tasks, each with a slug,
   dependencies, an exact file scope and checkable acceptance criteria,
   plus a *Shared interfaces* section that parallel tasks must agree on.
2. **Implementer report** (implementer → orchestrator): status, branch,
   worktree path, commit, checks run.
3. **Review** (reviewer → orchestrator): a verdict, acceptance criteria
   ticked off with evidence, and findings with severity, `file:line` and a
   concrete failure scenario.

If you change one of these formats, update every agent and skill that reads
it. `/feature` parses all three.

## `/feature`, phase by phase

```
preflight ─▶ plan ─▶ [human approves] ─▶ build wave 1 ─▶ review wave 1 ─▶ merge wave 1
                                              │                                │
                                              └──────── wave 2 … ◀────────────┘
                                                                               ▼
                                            final review of the whole feature ─▶ [human]
```

**Preflight.** The tree must be clean. Implementer worktrees are created from
a *commit* (see [worktree base](#where-worktrees-branch-from)), so anything
uncommitted would be invisible to them. The orchestrator creates
`feature/<slug>` if you're on the default branch.

**Plan.** The planner explores read-only and returns the plan. The
orchestrator shows it to you verbatim and **stops**. This is the cheapest
point to fix a misunderstanding: one edited sentence now saves a parallel
build in the wrong direction.

**Build.** Tasks are grouped into waves by dependency. Every task in a wave
is spawned in a single message, so they run concurrently. Each implementer
gets its own worktree (`isolation: worktree` in its frontmatter), builds,
tests, commits to its branch and reports. They never push and never touch
files outside their scope.

**Review.** One reviewer per finished task, also in parallel, with the diff
`feature/<slug>...<task-branch>`, the task and the implementer's report. A
`CHANGES_REQUESTED` verdict goes back to the **same** implementer (resumed,
so it keeps its worktree and context) for at most two rounds, then to you.

**Integrate.** Approved branches are merged into the feature branch with
`--no-ff` in plan order, and the checks run after each wave. A merge conflict
stops everything and is shown to you: two tasks touching the same file means
the plan was wrong, and that's worth knowing.

**Final review.** One reviewer reads the whole feature diff against the whole
plan. This catches seams: each piece was correct, but they don't fit together.

**Hand-back.** Merged worktrees and branches are removed. You get the task
table, verdicts, non-blocking findings and what's left. Nothing is pushed.

## Where worktrees branch from

`.claude/settings.json` sets:

```json
"worktree": { "baseRef": "head" }
```

so agent worktrees branch from your **current commit** rather than a fresh
copy of the default branch. That's what lets wave 2 build on wave 1's merged
work, and lets `/delegate` work on top of your feature branch. Remove the
setting if you'd rather every agent start from the default branch.

Worktrees live in `.claude/worktrees/` (gitignored). An agent worktree with no
changes is removed automatically. One with commits stays until it is merged
and removed by `/feature` or `/tidy`.

## `/delegate`

`/feature` without the planner and without integration: you describe one
task, the orchestrator writes a single task spec, one implementer builds it in
a worktree, one reviewer checks it, and you get the branch to merge when
you're ready. Use it for a bug fix or a test you want done while you keep
working in the main checkout.

## `/review`

Runs the `reviewer` agent in a forked context (`context: fork`,
`agent: reviewer`) on a branch, a range, or your current changes. There's no
plan, so it infers intent from the commit messages. Use it before opening a
PR, or on a teammate's branch.

## `/tidy`

Lists every worktree with its branch, merge state, unmerged commits and dirty
state, suggests what to remove, and removes only what you confirm, with safe
`git worktree remove` and `git branch -d`.

## Working in worktrees yourself

The same isolation works for humans. Start a session in its own worktree:

```bash
claude -w login-page
```

That creates `.claude/worktrees/login-page/` on branch `worktree-login-page`.
Run two or three of these in separate terminals to work on independent
features at once, each with its own Claude session, and use `/review` in each
before merging. `.worktreeinclude` lists gitignored files (like `.env`) that
are copied into every new worktree, so tests work there too.

## Failure modes and what happens

| Situation | What the orchestrator does |
|---|---|
| Dirty working tree at start | Stops and asks you to commit or stash |
| Plan has open questions | Shows them with the plan; waits for answers |
| Implementer is blocked | Shows you the blocker; continues tasks that don't depend on it |
| Implementer edits outside its scope | Reviewer marks it `blocking` |
| Two fix rounds didn't satisfy the reviewer | Escalates with the outstanding findings |
| Merge conflict between task branches | Stops; shows files and the tasks that touched them |
| Checks fail after a merge | Reports which wave broke them; doesn't push on |
| Tests in a worktree import the main checkout's code (editable install) | Implementer checks the import path before trusting results; use a worktree-safe test command in `CLAUDE.md` |
| An agent tries `git push --force`, `reset --hard` and the like | `guard-git.sh` blocks it; the agent has to ask you |
