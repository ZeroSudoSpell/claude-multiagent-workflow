---
name: feature
description: Orchestrate a feature end to end. Plan it with the planner agent, build each task in parallel in its own worktree with implementer agents, review every branch with the reviewer agent, then integrate onto a feature branch. Human approves the plan and the final result.
argument-hint: <feature description or issue link>
disable-model-invocation: true
---

# /feature: plan → parallel build → review → integrate

You are the **orchestrator**. You coordinate; you do not write feature code
yourself. Delegate building to `implementer`, judging to `reviewer`, and
planning to `planner`. Keep your own context small: work from the agents'
reports, not from reading every file they touched.

Feature request: $ARGUMENTS

## 0. Preflight

1. Run `git status --porcelain` and `git rev-parse --abbrev-ref HEAD`.
   - If the working tree is dirty, stop and ask the human to commit or stash.
     Implementer worktrees branch from the last commit, so uncommitted
     changes would be invisible to them.
2. Pick a short kebab-case slug for the feature. If you are on the default
   branch, create and switch to `feature/<slug>`. If you are already on a
   feature branch, stay on it.

## 1. Plan

1. Spawn the `planner` agent with the feature request, plus any issue text or
   constraints the human gave you.
2. Show the human the plan **verbatim**, and list the open questions.
3. **Stop and wait for approval.** Apply any edits the human asks for. Do not
   start building until they say go.

## 2. Build (parallel)

1. Group tasks into waves: wave 1 is every task with no dependencies; wave
   *n* is every task whose dependencies are all in earlier waves.
2. For each wave, spawn one `implementer` per task **in a single message** so
   they run concurrently. Each prompt must contain:
   - the task section from the plan, verbatim;
   - the **Shared interfaces** section;
   - the feature branch name it was branched from.
3. Collect every implementer report. Record a table of
   `task → status, branch, worktree, commit`.
4. Before starting the next wave, integrate the finished wave (step 4) so the
   next wave's worktrees branch from code that contains its dependencies.

If an implementer reports **blocked**, don't guess. Show the blocker to the
human and ask how to proceed. Carry on with tasks that don't depend on it.

## 3. Review (parallel)

1. For each `done` task, spawn a `reviewer` **in a single message** with:
   - the diff range `<feature-branch>...<task-branch>`;
   - the task section from the plan (including acceptance criteria);
   - the implementer's report.
2. For `CHANGES_REQUESTED`: resume the **same** implementer (it still has its
   worktree and context) with the blocking findings, then re-review. Allow at
   most **2** fix rounds per task; after that, escalate to the human with the
   outstanding findings.
3. `should-fix` and `nit` findings don't block. Collect them for the summary.

## 4. Integrate

For each approved task in plan order:

1. `git merge --no-ff <task-branch> -m "Merge <task id>: <title>"` into the
   feature branch.
2. On a conflict, stop. Show the human the conflicting files and which tasks
   touched them. Don't resolve conflicts by guessing.
3. After all of a wave's tasks are merged, run the test and lint commands from
   `CLAUDE.md` on the feature branch.

## 5. Final review and hand-back

1. Spawn one last `reviewer` on `<default-branch>...<feature-branch>` with the
   whole plan, to catch problems that only show up when the pieces meet.
2. Remove the worktrees and branches of merged tasks:
   `git worktree remove <path>` then `git branch -d <task-branch>`.
   Leave unmerged ones in place and list them.
3. Report to the human:
   - the plan's summary and the task table (status, review verdict, commit);
   - the final reviewer verdict and any non-blocking findings;
   - check results on the feature branch;
   - what's left: blocked tasks, open questions, follow-ups.

**Do not push and do not open a pull request.** The human decides when the
feature branch leaves this machine.
