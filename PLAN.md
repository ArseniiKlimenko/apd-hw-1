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
| R-4 | JSON item without `isCompleted`? | Decodes with `isCompleted = false`. | Matches the default of `StudyItem.init`; manual and JSON creation behave the same. |
| R-5 | Error type for domain violations found while decoding? | Propagate `StudyPlanError` unchanged; structural problems stay `DecodingError`. | Same rule gives the same error from `init` and from JSON; tests can compare exact `StudyPlanError` values. |
| R-6 | Which formats does `StudyPlan.decode(from:)` accept? | Top-level JSON array only. The keyed `{"items": [...]}` format is read by `JSONDecoder().decode(StudyPlan.self, from:)`. | Matches the task wording and the fixture; one method, one format. |

| R-7 | Which ID is reported when several IDs are duplicated? | The first repeat in detection order: scan left to right and report the first ID already seen (`[a, b, b, a]` → `"b"`). | Most common reading of "first duplicate"; single pass with early exit; reusable for the bonus. |
| R-8 | How are IDs compared? | Swift `String` equality, no normalization: `"A"`, `"a"` and `" a"` are different IDs. | Consistent with R-3 (IDs are not normalized). Swift equality is Unicode canonical equivalence, so `"\u{E9}"` and `"e\u{301}"` count as the same ID. |
| R-9 | Where does title-then-ID ordering apply? | Only to `items(in:)`; `items` keeps insertion order. | The bonus requires replacing items "at their current positions" and appending new IDs in ID order, which only makes sense if `items` is not re-sorted. Keeps JSON order on decode. |
| R-10 | How are titles compared? | `localizedStandardCompare` (case-insensitive, numeric-aware, locale-aware, e.g. `"Item 2"` before `"Item 10"`). Ties (`.orderedSame`) are broken by `id` using `<`. | Student's choice: human-friendly order, including the Ukrainian alphabet. The agent recommended `<` for strict determinism; the locale risk is accepted and recorded under Risks. |

| R-11 | What if `incompleteMinutes()` overflows `Int`? | Plain `+`: Swift traps on overflow. | Never returns a wrong number; standard Swift behavior; no rule beyond the task. `&+` would silently return a negative sum, saturation would hide the problem, and throwing or returning an optional would change the public API. |
| R-12 | Bonus: what does "replace" mean for an existing ID? | Full replacement: the imported item (including its `isCompleted`) takes the existing item's position. | Literal reading of "replace"; `items[i] == imported`; no extra rule. |
| R-13 | Bonus: how are new IDs ordered? | `localizedStandardCompare` on `id` (e.g. `"item-2"` before `"item-10"`, case-insensitive); `.orderedSame` falls back to `<`. | Student's choice, consistent with R-10. The agent recommended `<`; the locale risk is recorded under Risks. |
| R-14 | Bonus: how is atomicity guaranteed? | Check incoming duplicates first, build the result in a local copy, then assign `self = try StudyPlan(items: merged)` once at the end. | Any failure before the last line leaves the plan untouched by construction; the initializer re-checks ID uniqueness. |
| R-15 | Bonus: which incoming duplicates are rejected? | Any repeated ID inside `importedItems`, even with identical content; the first repeat in detection order is reported (as R-7). An imported ID that already exists in the plan is a replacement, not a duplicate. | "Reject duplicate incoming IDs" is about IDs, not content; same helper and semantics as `init`. |
| R-16 | Bonus: empty import? | No change, no error. | Nothing to merge; throwing would need a new error case (API change). |

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

### Task 2 — Codable boundaries

- Decoding a `StudyItem` goes through the validating initializer: a blank
  title throws `.blankTitle`, non-positive minutes throw
  `.nonPositiveEstimatedMinutes` (R-5).
- A missing `isCompleted` decodes as `false` (R-4).
- Structural problems (missing required key, wrong value type, unknown
  category, malformed JSON) throw `DecodingError`.
- `StudyPlan` decodes from the keyed `{"items": [...]}` format, validating
  every item.
- `StudyPlan.decode(from:)` decodes a top-level array (the fixture decodes to
  three items in file order); `[]` gives an empty plan; a keyed object is
  rejected with `DecodingError.typeMismatch` (R-6).
- Encoding stays synthesized: an item and a plan round-trip through
  `JSONEncoder`/`JSONDecoder` unchanged; a plan encodes as `{"items": [...]}`.
- Duplicate-ID rejection during decoding is covered in task 3, because it
  depends on R-7.

### Task 3 — Duplicates and ordering

- `StudyPlan(items:)` throws `.duplicateID(id)` for the first repeat in
  detection order (R-7): `[a, b, a]` → `"a"`, `[a, b, b, a]` → `"b"`,
  `[c, a, c, a]` → `"c"`.
- IDs differing only in case or whitespace are not duplicates (R-8).
- Duplicates are rejected through both JSON entry points (keyed decoding and
  `decode(from:)`).
- `items` keeps insertion order (R-9).
- `items(in:)` returns the category's items ordered by title using
  `localizedStandardCompare`, then by `id` (R-10): case-insensitive
  (`"Apple"`, `"banana"`, `"Cherry"`) and numeric-aware (`"Item 2"` before
  `"Item 10"`); equal titles are ordered by `id`; the result does not depend
  on insertion order.

### Task 4 — Queries and completion

- `items(in:)` returns only that category's items; a category without items
  and an empty plan give `[]`.
- `incompleteMinutes()` sums `estimatedMinutes` of items with
  `isCompleted == false` (fixture: 45 + 90 = 135); it is `0` for an empty
  plan and when everything is completed.
- `markCompleted(id:)` sets `isCompleted` of that item only; other items and
  the order of `items` are unchanged.
- An unknown ID (including one differing only in case, R-8) throws
  `.unknownID(id)` and leaves the plan unchanged.
- Completion is idempotent: marking an already completed item again does not
  throw and changes nothing.
- Completion is visible in `items(in:)`, `incompleteMinutes()` and in encoded
  JSON.

### Bonus — `importMerging(_:)`

- Existing IDs are replaced at their current positions, in full (R-12);
  positions come from the plan, not from the import order.
- New IDs are appended after all existing items, ordered with
  `localizedStandardCompare` (R-13): `[c✓, a, e]` + `[d, a′, b]` →
  `[c✓, a′, e, b, d]`.
- Duplicate incoming IDs (even identical items) throw `.duplicateID` for the
  first repeat in detection order (R-15), and the plan is unchanged — also
  when the same import would otherwise have replaced existing items (R-14).
- An empty import changes nothing and does not throw (R-16).
- The merged plan keeps working with `items(in:)`, `incompleteMinutes()` and
  `markCompleted(id:)`.

## Implementation steps

1. Task 1 — tests in `Tests/StudyPlannerTests/StudyItemValidationTests.swift`,
   then implement `StudyItem.init` in `Sources/StudyPlanner/StudyPlanner.swift`.
2. Task 2 — tests in `Tests/StudyPlannerTests/StudyPlanCodableTests.swift`,
   then `StudyItem.init(from:)`, `StudyPlan.init(from:)`,
   `StudyPlan.decode(from:)`, and a storing-only `StudyPlan.init(items:)`.
3. Task 3 — tests in
   `Tests/StudyPlannerTests/StudyPlanDuplicatesAndOrderingTests.swift`, then
   the duplicate-ID check in `StudyPlan.init(items:)` and `items(in:)`
   (filter + title-then-ID ordering) with private helpers.
4. Task 4 — tests in
   `Tests/StudyPlannerTests/StudyPlanQueriesAndCompletionTests.swift`, then
   `incompleteMinutes()`, `markCompleted(id:)` and an `internal` completion
   helper on `StudyItem` (needed because `isCompleted` is `private(set)`).
   `items(in:)` was implemented in task 3.
5. Optional bonus — tests in
   `Tests/StudyPlannerTests/StudyPlanImportMergingTests.swift`, then
   `importMerging(_:)` reusing `firstDuplicateID(in:)`, with an `id → index`
   dictionary and a private new-ID ordering helper.

## Risks

- Until task 4 is done, unimplemented `fatalError` stubs crash the whole test
  process, so intermediate runs use `swift test --filter`; the final check is
  exactly `swift test`.
- A title made only of format characters such as U+200D is accepted as
  non-blank (deliberate consequence of R-2).
- Hidden tests may assert exact stored titles; storing as given (R-1) avoids
  silently altering input.
- Synthesized `Decodable` assigns stored properties directly and would bypass
  validation; explicit `init(from:)` implementations are required for both
  `StudyItem` and `StudyPlan`.
- R-5: a propagated `StudyPlanError` carries no `codingPath`, so the caller
  does not learn which array element was invalid.
- R-6: `StudyPlan.decode(from:)` cannot read what `JSONEncoder().encode(plan)`
  produces (`{"items": [...]}`); plan round-trips must use
  `JSONDecoder().decode(StudyPlan.self, from:)`. A hidden test passing a keyed
  object to `decode(from:)` would fail; the task wording ("top-level JSON-array
  decoding") makes this unlikely. A wrong format yields a generic
  `DecodingError.typeMismatch`.
- Until task 3, `StudyPlan.init(items:)` stores items without the duplicate-ID
  check. (Resolved in task 3.)
- R-7: the reported ID depends on input order (`[a, b, b, a]` → `"b"`,
  `[b, a, a, b]` → `"a"`); this is intentional and covered by a test.
- R-8: canonically equivalent IDs (`"\u{E9}"` vs `"e\u{301}"`) are treated as
  duplicates although their bytes differ.
- R-10: `localizedStandardCompare` uses the current locale, and Apple
  documents that its exact behavior differs between locales and may change in
  future OS releases. On the grader's machine the order can differ from the
  local one: e.g. Latin vs Cyrillic titles swap places between `en_US` and
  `uk_UA`, and some locales put uppercase before lowercase. Mitigation: the
  student tests use only titles whose relative order is the same in every
  locale (plain Latin letters with different first letters, and numeric
  suffixes); a hidden test expecting plain `<` ordering (e.g. `"B"` before
  `"a"`) would fail.
- R-11: any positive `estimatedMinutes` is valid, so items with huge values
  (e.g. `Int.max`, reachable from JSON) make `incompleteMinutes()` trap on
  overflow. `Int.max` minutes is about 17.5 trillion years, so this is
  accepted; a trap cannot be caught by XCTest, so it is documented rather
  than tested.
- R-12: a full replacement can reset progress (an imported item with
  `isCompleted: false` replaces a completed one).
- R-13: new-ID order has the same locale dependence as R-10. A hidden test
  expecting plain `<` order for new IDs (e.g. `"B"` before `"a"`, or
  `"item-10"` before `"item-2"`) would fail. Student tests use only IDs whose
  relative order is the same in every checked locale.

## `swift test` verification

| Date | Command | Result | Follow-up |
| --- | --- | --- | --- |
| 2026-09-29 | `swift test` (untouched template) | Crash: `Fatal error: Implement StudyItem validation` (signal 5) | Expected starting state. |
| 2026-09-29 | `swift test --filter StudyItemValidationTests` (tests written, stub unchanged) | Crash at `Implement StudyItem validation` | Red phase confirmed; implement `StudyItem.init`. |
| 2026-09-29 | `swift test --filter 'StudyItemValidationTests\|StudyPlannerPublicTests/testValidItemStoresValues\|StudyPlannerPublicTests/testBlankTitleIsRejected'` | 9 tests, 0 failures ([log](artifacts/task1-swift-test.txt)) | Task 1 done. |
| 2026-09-29 | `swift test` | Crash at `Implement plan validation` in `testIncompleteMinutesAndCompletion` | Expected until tasks 3–4. |
| 2026-09-29 | `swift test --filter 'StudyPlanCodableTests/(testDecodingItem\|testItemRoundTrips)'` (synthesized decoder) | 6 tests, 3 failures: blank title and zero minutes decode without error; missing `isCompleted` throws `keyNotFound` ([log](artifacts/task2-red-synthesized-decoder.txt)) | Red phase confirmed the validation bypass; implement explicit `init(from:)`. |
| 2026-09-29 | `swift test --filter 'StudyPlanCodableTests\|StudyItemValidationTests\|StudyPlannerPublicTests/testValidItemStoresValues\|StudyPlannerPublicTests/testBlankTitleIsRejected'` | 23 tests, 0 failures ([log](artifacts/task2-swift-test.txt)) | Task 2 done. |
| 2026-09-29 | `swift test` | Crash at `Implement completion mutation` in `testIncompleteMinutesAndCompletion` | Expected until task 4. |
| 2026-09-30 | `swift test --filter 'StudyPlanDuplicatesAndOrderingTests/(testDuplicate\|testFirstRepeat\|testIDsDiffering\|testCanonically)'` (no duplicate check yet) | 6 tests, 8 assertion failures (`did not throw`) ([log](artifacts/task3-red-duplicates.txt)); ordering tests crash at `Implement category query` | Red phase confirmed; implement duplicate check and `items(in:)`. |
| 2026-09-30 | `swift test --filter 'StudyPlanDuplicatesAndOrderingTests\|StudyPlanCodableTests\|StudyItemValidationTests\|StudyPlannerPublicTests/testValidItemStoresValues\|StudyPlannerPublicTests/testBlankTitleIsRejected'` | 35 tests, 0 failures ([log](artifacts/task3-swift-test.txt)) | Task 3 done. |
| 2026-09-30 | `swift test` | Crash at `Implement completion mutation` | Expected until task 4. |
| 2026-09-30 | `swift test --filter StudyPlanQueriesAndCompletionTests` (stubs unchanged) | Crash at `Implement completion mutation` ([log](artifacts/task4-red.txt)) | Red phase confirmed; implement `incompleteMinutes()` and `markCompleted(id:)`. |
| 2026-09-30 | `swift test` | **47 tests, 0 failures, exit code 0** ([log](artifacts/swift-test-full.txt)) | Tasks 1–4 done. Public declarations checked against the template (`git show aca442f:…`): identical apart from the two `public init(from:)` `Decodable` implementations; `StudyPlannerPublicTests.swift` unchanged. |
| 2026-09-30 | `swift test --filter StudyPlanImportMergingTests` (stub unchanged) | Crash at `Implement optional bonus` ([log](artifacts/bonus-red.txt)) | Red phase confirmed; implement `importMerging(_:)`. |
| 2026-09-30 | `swift test` | **58 tests, 0 failures, exit code 0** ([log](artifacts/swift-test-final.txt)) | Bonus done. Public declarations re-checked against `aca442f` (identical apart from the two `public init(from:)`); starter tests and fixture unchanged; no `fatalError` stubs left. |
