---
name: delegate
description: Hand one self-contained task to an implementer agent in an isolated worktree, then have the reviewer check it. Lighter than /feature. Use for a bug fix, small refactor or test addition you want done off to the side while you keep working.
argument-hint: <task description>
disable-model-invocation: true
---

# /delegate: one task, one worktree, one review

Task: $ARGUMENTS

1. Run `git status --porcelain`. If the tree is dirty, warn the human that the
   implementer will branch from the last commit and won't see those changes.
   Continue only if they confirm.
2. Write a task spec in the planner's task format (slug, files, do,
   acceptance). Infer the file scope from a quick `Grep`/`Glob`. If the scope
   is unclear or the task looks like more than one task, suggest `/feature`
   instead and stop.
3. Spawn one `implementer` with the task spec. Tell the human the agent has
   started, so they can keep working while it runs.
4. When it reports `done`, spawn a `reviewer` on
   `<current-branch>...<task-branch>` with the spec and the report.
5. On `CHANGES_REQUESTED`, resume the same implementer with the blocking
   findings. Allow one fix round, then re-review. If it's still not approved,
   hand it back to the human.
6. Report: the branch, the worktree path, the commit, the review verdict and
   its findings, and the command to take the change:

   ```bash
   git merge --no-ff <task-branch>
   ```

   Don't merge it yourself unless the human asks.
