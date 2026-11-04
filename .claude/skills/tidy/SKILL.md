---
name: tidy
description: List agent and feature worktrees with their branch, merge state and uncommitted changes, then offer to remove the ones that are merged or empty. Use after /feature or /delegate runs, or when `git worktree list` has grown long.
disable-model-invocation: true
allowed-tools: Bash(git worktree list *), Bash(git status *), Bash(git branch *), Bash(git log *), Bash(git rev-list *), Bash(git symbolic-ref *)
---

# /tidy: clean up worktrees

1. Find the default branch: `git symbolic-ref --short refs/remotes/origin/HEAD`
   (strip `origin/`; fall back to `main`).
2. Run `git worktree list --porcelain`. Skip the main checkout.
3. For each remaining worktree, collect:
   - its branch;
   - whether the branch is merged into the current branch or the default
     branch (`git branch --merged`);
   - commits not yet merged (`git rev-list --count <default>..<branch>`);
   - uncommitted changes (`git -C <path> status --porcelain`).
4. Show one table: path, branch, merged?, unmerged commits, dirty?, and a
   suggested action:
   - **remove**: merged and clean, or no commits and clean;
   - **keep**: has unmerged commits or uncommitted changes.
5. Ask the human which to remove. Only after they confirm, for each one run
   `git worktree remove <path>`, then `git branch -d <branch>`. Use `-d`, not
   `-D`. If git refuses because the branch isn't merged, report that and leave
   it in place.
6. Finish with `git worktree prune` and show the new `git worktree list`.

Never use `--force` on `git worktree remove` or `-D` on `git branch`; the
`guard-git.sh` hook blocks both. If the human wants a dirty or unmerged
worktree gone, give them the exact commands to run themselves.
