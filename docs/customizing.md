# Customizing

Everything here is plain Markdown and JSON in `.claude/`. Change it in a pull
request and every teammate's workflow changes with it. CI
(`scripts/validate.py`) catches the common mistakes: a typo'd frontmatter
field, a skill that forks into an agent that doesn't exist, a hook script
that isn't executable.

## Tell the agents about your project

Fill in the **Commands** table and **Conventions** in `CLAUDE.md`. Every agent
reads it. The most common reason an implementer "finishes" with broken tests
is that it guessed the test command.

When an agent keeps making the same mistake, add one line to Conventions.
That's cheaper than adding rules to every agent.

## Raise the review bar

- Add project rules to the end of `.claude/review/checklist.md` (there's a
  commented example). The reviewer applies them on every review.
- Add another focused pass, like `.claude/review/performance.md` or
  `.claude/review/accessibility.md`, and add a line to step 2 of
  `.claude/agents/reviewer.md` saying when to apply it.

## Pick models

Model choice is per agent, in the `model:` frontmatter field (`opus`,
`sonnet`, `haiku`, a full model ID, or `inherit` to use the session's model).
The defaults put the strongest model where judgment matters and a cheaper one
where volume is:

- `planner: opus`: a bad plan wastes every parallel build after it.
- `reviewer: opus`: it's the last check before a human.
- `implementer: sonnet`: there are several running at once, each with a
  tightly scoped task.

Set `implementer` to `inherit` if you'd rather it follow your session.

## Add an agent

Create `.claude/agents/<name>.md`:

```markdown
---
name: migrator
description: Writes and verifies reversible database migrations. Use when a task changes the schema.
tools: Read, Grep, Glob, Edit, Write, Bash
model: sonnet
isolation: worktree
---

<instructions, rules, and a fixed report format>
```

Give it a **fixed output format** if the orchestrator will read its result.
Then reference it from a skill, or just ask Claude to use it. The
`description` is what Claude uses to decide when the agent fits, so say *when*
to use it, not just what it is.

## Permissions

`.claude/settings.json` pre-approves read-only git commands, so agents don't
prompt for `git diff` and `git log`, and denies reading `.env` files and keys.
Add your test and lint commands so implementers don't stop to ask:

```json
"allow": [
  "Bash(npm test *)",
  "Bash(npm run lint *)"
]
```

Personal preferences go in `.claude/settings.local.json`, which is
gitignored.

## The git guard

`.claude/hooks/guard-git.sh` runs before every Bash command, from the main
session and from subagents, and blocks:

- force pushes (`--force`, `-f`, `+refspec`), and any push to
  `main`/`master`/`trunk`/`develop`/`release/*`;
- pushes that delete or mirror refs;
- `git reset --hard`, `git clean -f`, `git branch -D`,
  `git worktree remove --force`, `git checkout -- .` and `git restore .`.

Edit the `protected` pattern in the script to match your branch names. The
cases it must allow and block are in `tests/test_guard_git.sh`. Add one when
you change it.

It's a guardrail against an agent doing something you'd regret, not a
sandbox. A determined command can get around a regex. For hard isolation, run
Claude Code in a container or with sandboxing enabled.

## Format on save

A common addition is a `PostToolUse` hook that formats whatever an agent just
edited:

```json
"PostToolUse": [
  {
    "matcher": "Edit|Write",
    "hooks": [
      { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/format.sh" }
    ]
  }
]
```

`format.sh` reads the hook JSON on stdin and runs your formatter on
`.tool_input.file_path`.

## Worktree base

`"worktree": { "baseRef": "head" }` makes agent worktrees start from your
current commit. Delete it to have them start from the default branch instead.
`/feature` then can't build later waves on earlier ones, so only do this if
you mostly use `/delegate` for independent fixes.

## Agent teams

Claude Code also has an experimental *agent teams* mode, where named
teammates message each other directly. This template doesn't depend on it:
subagents plus worktrees work in every interactive and headless session, and
the orchestrator-in-the-middle design keeps a single place where you approve
things. Agent teams haven't been tested with this setup. If you try them,
note that while they're enabled, Claude may run named subagents as teammates.
