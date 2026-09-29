# Agent worklog

Use one entry for each tool-assisted or agent-assisted task. Do not include secrets, tokens, private prompts, or sensitive session data.

Tool used: Claude Code (Claude Opus 5.5), working in this repository.

---

## Entry 1 — Planning for tasks 1–4

### Tool/agent task

Asked the agent to read the template (API, starter tests, fixture, task list)
and, without writing code, propose an implementation plan for tasks 1–4, list
edge cases and risks, and mark the decisions that are mine to make.

### Output reviewed

A per-task plan, edge-case lists, risks (validation bypass by synthesized
`Decodable`, `fatalError` stubs crashing the whole test run, locale-dependent
sorting, `private(set)` on `isCompleted`, `Int` overflow) and decisions R-1 …
R-11. I also asked for explanations of what "public API" means for this
assignment and of the repository structure.

### Accepted/rejected/revised decision

- Accepted R-1 (store title as given), R-2 (standard
  `.whitespacesAndNewlines` blank check), R-3 (no `id` validation).
- Revised: the agent first claimed U+200B is not trimmed by
  `.whitespacesAndNewlines`; after a local check it corrected this (U+200B is
  trimmed; U+200D, U+2060, U+FEFF are not). The corrected facts are in
  `PLAN.md`.
- R-4 … R-11 deferred until the corresponding tasks.

### Verification command/result

`swift test` on the untouched template: crashes at
`Fatal error: Implement StudyItem validation` (expected starting state).

### Artifact links

- [PLAN.md](PLAN.md)

---

## Entry 2 — Task 1: validation and errors

### Tool/agent task

Implement `StudyItem.init` validation according to R-1 … R-3, test-first, with
student tests in a separate file.

### Output reviewed

- `Tests/StudyPlannerTests/StudyItemValidationTests.swift` — 7 tests: all
  values stored as given, empty title, whitespace-only titles (incl. NBSP,
  U+3000), non-positive minutes (`0`, `-1`, `Int.min`), `1` accepted,
  title-before-minutes precedence, empty `id` accepted. Error cases are checked
  for the exact `StudyPlanError` value, not just "some error".
- `Sources/StudyPlanner/StudyPlanner.swift` — body of `StudyItem.init` only;
  no signatures or access modifiers changed.

### Accepted/rejected/revised decision

I am working in manual mode in claude code, so I can see a diff before accept every change and only after reviewing each diff I make my desicion. This time after my review of each diff - I accepted each change

### Verification command/result

- Red: `swift test --filter StudyItemValidationTests` before implementation —
  crash at `Implement StudyItem validation`.
- Green: `swift test --filter 'StudyItemValidationTests|StudyPlannerPublicTests/testValidItemStoresValues|StudyPlannerPublicTests/testBlankTitleIsRejected'`
  — 9 tests, 0 failures.
- Full `swift test` still crashes at `Implement plan validation` (expected
  until tasks 3–4).

### Artifact links

- [artifacts/task1-swift-test.txt](artifacts/task1-swift-test.txt)
