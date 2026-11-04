---
name: review
description: Run the team review checklist against a branch, a diff range, or the current changes, in an isolated reviewer context. Use before opening a PR or when a teammate asks for a second opinion.
argument-hint: "[branch | base...head]  (default: current changes vs default branch)"
context: fork
agent: reviewer
---

Review target: $ARGUMENTS

Work out the diff range:

- If the target is empty: find the default branch with
  `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`; fall
  back to `main`). Review `<default>...HEAD` **and** the uncommitted changes
  from `git diff HEAD`.
- If it contains `...` or `..`, use it as given.
- If it's a branch name, review `<default>...<branch>`.

There is no plan for this review. Infer the intent from the commit messages
(`git log --format='%s%n%b' <range>`) and judge the change against that
intent, plus the checklist.

Follow your normal process and output format.
