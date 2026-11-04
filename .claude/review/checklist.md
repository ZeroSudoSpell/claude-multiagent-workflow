# Review checklist

The `reviewer` agent applies this on every review. It is the team's shared bar:
edit it in a PR like any other code, and every teammate's reviews change with
it.

Each item is a question. If the answer is "no" and it matters, it's a finding.
The reviewer agent decides the severity using its own rubric: blocking,
should-fix or nit.

## 1. Does it do what was asked?
- Is every acceptance criterion met, with evidence (a test, a command, a line)?
- Does the change do anything that *wasn't* asked? Unrequested refactors,
  renames and "while I was here" fixes are out of scope.
- Were only the files in the task's scope modified?

## 2. Is it correct?
- Edge cases: empty input, one element, very large input, unicode, missing
  optional fields, zero, negative numbers, duplicates.
- Error paths: what happens when the I/O, network or parse fails? Are errors
  surfaced, or swallowed?
- State: any shared mutable state, ordering assumptions, races, or resources
  (files, connections, locks) that aren't released on every path?
- Off-by-one, inclusive vs exclusive bounds, time zones, float comparisons.
- Does it break an existing caller? Search for usages of anything whose
  signature or behaviour changed.

## 3. Is it tested?
- Does a test fail without the change and pass with it?
- Are the error paths and edge cases above covered, not just the happy path?
- Do the tests assert on behaviour, not on implementation details or mocks of
  the thing under test?
- Do the tests pass, and is the lint clean?

## 4. Will the next person understand it?
- Do the names say what things are? Is there a comment where the *why* isn't
  obvious from the code?
- Is there dead code, commented-out code, or a debug print left behind?
- If the change affects users or operators, are the docs, changelog or help
  text updated?

## 5. Does it fit the codebase?
- Does it reuse existing helpers instead of re-implementing them?
- Does it follow the conventions in `CLAUDE.md` and the surrounding code?
- Is a new dependency justified, and is it pinned the way the others are?

<!--
Add project-specific checks below, e.g.:

## 6. Project rules
- Every new API endpoint has an entry in docs/api.md.
- Database migrations are reversible.
- No new `any` types in TypeScript.
-->
