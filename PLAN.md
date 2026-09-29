# Plan

## Scope

Implement the `StudyPlanner` domain behavior (tasks 1–4, then optionally the
`importMerging` bonus) without changing the published public API or the
supplied public tests in `StudyPlannerPublicTests.swift`.

Allowed changes: method bodies, `internal`/`private` helpers, and explicit
implementations of already-declared protocol requirements (for example
`public init(from:)` for `Decodable`). Not allowed: renaming, changing
parameters, return types, `throws`, access modifiers, protocol conformances, or
the cases of `StudyPlanError`.

Work proceeds one task at a time, test-first. Student tests live in separate
files, one `XCTestCase` subclass per task.

## Decisions

| ID | Question | Decision | Reason |
| --- | --- | --- | --- |
| R-1 | Store `title` trimmed or as given? | As given; trimming is used only for the blank check. | No normalization is required; keeps exact values, JSON round-trips and sorting predictable. |
| R-2 | What counts as "blank"? | Empty after `trimmingCharacters(in: .whitespacesAndNewlines)`. | Standard, well-known definition; covers spaces, tabs, newlines, NBSP, U+3000, U+2028, U+0085, U+200B. Format characters (U+200D, U+2060, U+FEFF) are not whitespace and are used in valid text (emoji ZWJ sequences). |
| R-3 | Validate `id`? | No. | `StudyPlanError` has no case for it; adding one would change the public API. |

Decisions for tasks 2–4 (R-4 … R-11) are recorded before each task starts.

## Acceptance criteria

### Task 1 — Validation and errors

- A valid item stores every value exactly as given, including a title with
  surrounding whitespace and an explicit `isCompleted: true`.
- `isCompleted` defaults to `false`.
- An empty or whitespace-only title throws `StudyPlanError.blankTitle`.
- `estimatedMinutes <= 0` (including `Int.min`) throws
  `StudyPlanError.nonPositiveEstimatedMinutes`; `1` is accepted.
- When both are invalid, `blankTitle` is thrown (title before minutes).
- An empty `id` is accepted (R-3).

### Tasks 2–4 and bonus

To be detailed before each task starts.

## Implementation steps

1. Task 1 — tests in `Tests/StudyPlannerTests/StudyItemValidationTests.swift`,
   then implement `StudyItem.init` in `Sources/StudyPlanner/StudyPlanner.swift`.
2. Task 2 — Codable boundaries (`StudyItem.init(from:)`, `StudyPlan.init(from:)`,
   `StudyPlan.decode(from:)`).
3. Task 3 — duplicate IDs in `StudyPlan.init(items:)` and title-then-ID ordering.
4. Task 4 — `items(in:)`, `incompleteMinutes()`, `markCompleted(id:)`.
5. Optional bonus — `importMerging(_:)`.

## Risks

- Until task 4 is done, unimplemented `fatalError` stubs crash the whole test
  process, so intermediate runs use `swift test --filter`; the final check is
  exactly `swift test`.
- A title made only of format characters such as U+200D is accepted as
  non-blank (deliberate consequence of R-2).
- Hidden tests may assert exact stored titles; storing as given (R-1) avoids
  silently altering input.

## `swift test` verification

| Date | Command | Result | Follow-up |
| --- | --- | --- | --- |
| 2026-09-29 | `swift test` (untouched template) | Crash: `Fatal error: Implement StudyItem validation` (signal 5) | Expected starting state. |
| 2026-09-29 | `swift test --filter StudyItemValidationTests` (tests written, stub unchanged) | Crash at `Implement StudyItem validation` | Red phase confirmed; implement `StudyItem.init`. |
| 2026-09-29 | `swift test --filter 'StudyItemValidationTests\|StudyPlannerPublicTests/testValidItemStoresValues\|StudyPlannerPublicTests/testBlankTitleIsRejected'` | 9 tests, 0 failures ([log](artifacts/task1-swift-test.txt)) | Task 1 done. |
| 2026-09-29 | `swift test` | Crash at `Implement plan validation` in `testIncompleteMinutesAndCompletion` | Expected until tasks 3–4. |
