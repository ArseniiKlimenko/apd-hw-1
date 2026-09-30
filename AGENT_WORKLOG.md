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

---

## Entry 3 — Task 2: Codable boundaries

### Tool/agent task

Asked the agent to explain how `init(from:)` works and why explicit
implementations are needed, to detail the trade-offs of R-5 and the risks of
R-6, and then to implement task 2 test-first according to R-4 (missing
`isCompleted` → `false`), R-5 (option A: propagate `StudyPlanError`
unchanged) and R-6 (`decode(from:)` accepts a top-level array only).

### Output reviewed

- `Tests/StudyPlannerTests/StudyPlanCodableTests.swift` — 14 tests: item
  decoding (blank title, zero minutes, missing `isCompleted`, missing required
  key, wrong value types / unknown category, round-trip), keyed plan decoding
  (order preserved, item error propagated, round-trip and `{"items": …}`
  shape), `decode(from:)` (fixture, `[]`, item error propagated, keyed object
  rejected, malformed JSON).
- `Sources/StudyPlanner/StudyPlanner.swift` — private `CodingKeys` and
  `public init(from:)` for `StudyItem` and `StudyPlan` (implementations of the
  existing `Decodable` requirement), body of `decode(from:)`, and a
  storing-only `StudyPlan.init(items:)` (duplicate check deferred to task 3
  because it depends on R-7). Encoding stays synthesized.
- Agent corrections during this task:
  - It had claimed a global `static let decoder = JSONDecoder()` causes Swift 6
    concurrency problems; a local check showed it compiles cleanly
    (`JSONDecoder` is `Sendable`). A local decoder is still used, for
    simplicity.
  - The first red run mixed two causes: the blank-title and zero-minute JSON
    lacked `isCompleted`, so the synthesized decoder failed on the missing
    key rather than exposing the validation bypass. Those two tests now
    include `"isCompleted": false`, so each test checks one rule.

### Accepted/rejected/revised decision

I accepted the AI's suggestions regarding key parts of this component, but only after analyzing the pros, cons, and risks of the proposed solutions. My choices prioritized ease of implementation—ensuring the solution covered most potential edge cases—and clarity; for instance, the absence of an `isCompleted` flag implies `false`. A specific example of choosing a simpler implementation despite its downsides—because it still satisfied the necessary logic—is how the decoder handles JSON that violates a domain rule (such as an empty `title`): it throws the same `StudyPlanError` as the standard initializer rather than wrapping it in a `DecodingError`. This ensures that a single rule always results in a specific error that tests can precisely verify.

### Verification command/result

- Red: `swift test --filter 'StudyPlanCodableTests/(testDecodingItem|testItemRoundTrips)'`
  against the synthesized decoder — 6 tests, 3 failures (blank title and zero
  minutes decoded without error; missing `isCompleted` threw `keyNotFound`).
- Green: `swift test --filter 'StudyPlanCodableTests|StudyItemValidationTests|StudyPlannerPublicTests/testValidItemStoresValues|StudyPlannerPublicTests/testBlankTitleIsRejected'`
  — 23 tests, 0 failures.
- Full `swift test` now crashes at `Implement completion mutation` (expected
  until task 4).

### Artifact links

- [artifacts/task2-red-synthesized-decoder.txt](artifacts/task2-red-synthesized-decoder.txt)
- [artifacts/task2-swift-test.txt](artifacts/task2-swift-test.txt)

---

## Entry 4 — Task 3: duplicates and ordering

### Tool/agent task

Asked the agent to list and compare all options for R-7 (which duplicate ID
to report), to explain R-9 (where ordering applies) and R-10 (how titles are
compared) in detail, and then to implement task 3 test-first according to
R-7 A (first repeat in detection order), R-8 (plain Swift `String` equality
for IDs), R-9 (`items` keeps insertion order; only `items(in:)` is sorted)
and R-10 (`localizedStandardCompare` for titles). I stopped the agent before
accepting the private helpers and asked for a plain-language explanation of
`firstDuplicateID` and `isOrderedBefore`, then accepted the same change.

### Output reviewed

- `Tests/StudyPlannerTests/StudyPlanDuplicatesAndOrderingTests.swift` — 12
  tests: duplicate ID, first repeat in detection order (`[a,b,b,a]` → `b`,
  `[b,a,a,b]` → `a`, `[c,a,c,a]` → `c`, triple repeat), case/whitespace IDs
  are distinct, canonically equivalent IDs are duplicates, duplicates via
  keyed JSON and via `decode(from:)`, `items` insertion order, title order,
  equal titles ordered by ID, case-insensitive and numeric-aware titles,
  order independent of input permutation.
- `Sources/StudyPlanner/StudyPlanner.swift` — duplicate check in
  `StudyPlan.init(items:)`, body of `items(in:)` (filter + sort), and two
  `private static` helpers: `firstDuplicateID(in:)` and `isOrderedBefore`.
- R-10 differs from the agent's recommendation (`<`, strictly deterministic).
  The agent documented the locale risk in `PLAN.md` and checked with a local
  script that the titles used in the tests sort identically under the
  `localizedStandardCompare` options in en_US, uk_UA, da_DK, de_DE, tr_TR,
  ja_JP and sv_SE.

### Accepted/rejected/revised decision

The solutions in this section were more straightforward, though there were plenty of options; my choice reflects my personal perspective, even though I understand the scenarios where alternative implementations might be preferred. Regarding which ID to return when duplicates exist in the plan, I didn't reinvent the wheel; I chose the simplest implementation—returning the first ID that repeats an earlier one, scanning left to right. Comparing IDs was also a simple decision—an exact match—and I avoided normalization elsewhere to minimize the risk of overlooking potential edge cases. Comparing titles, however, was trickier; while I could have compared strings based on Unicode character codes, I ultimately opted for `localizedStandardCompare`. This type of sorting feels more natural to me; since the app is simple and this internal functionality is visible to the user, it is better for the behavior to align with human perception.

### Verification command/result

- Red: `swift test --filter 'StudyPlanDuplicatesAndOrderingTests/(testDuplicate|testFirstRepeat|testIDsDiffering|testCanonically)'`
  — 6 tests, 8 assertion failures (`did not throw`); the negative
  case/whitespace test already passed. Ordering tests crashed at
  `Implement category query`.
- Green: `swift test --filter 'StudyPlanDuplicatesAndOrderingTests|StudyPlanCodableTests|StudyItemValidationTests|StudyPlannerPublicTests/testValidItemStoresValues|StudyPlannerPublicTests/testBlankTitleIsRejected'`
  — 35 tests, 0 failures.
- Full `swift test` still crashes at `Implement completion mutation`
  (expected until task 4).

### Artifact links

- [artifacts/task3-red-duplicates.txt](artifacts/task3-red-duplicates.txt)
- [artifacts/task3-swift-test.txt](artifacts/task3-swift-test.txt)

---

## Entry 5 — Task 4: queries and completion

### Tool/agent task

Asked the agent to explain the options for R-11 (`Int` overflow in
`incompleteMinutes()`) in plain language, and then to implement task 4
test-first according to R-11 (plain `+`, trap on overflow), with
`markCompleted(id:)` throwing `.unknownID` for unknown IDs and being
idempotent for already completed items.

### Output reviewed

- `Tests/StudyPlannerTests/StudyPlanQueriesAndCompletionTests.swift` — 11
  tests: category query per category (fixture), category without items,
  empty plan (all categories and zero minutes), incomplete-minute sum
  (fixture, 135), zero when everything is completed, completion changes only
  that item, unknown IDs (`"nope"`, `"A"`, `" a"`, `""`) throw and leave the
  plan unchanged, unknown ID on an empty plan, idempotent completion,
  completing an item already completed in the fixture, completion visible in
  queries and encoded JSON.
- `Sources/StudyPlanner/StudyPlanner.swift` — bodies of `incompleteMinutes()`
  and `markCompleted(id:)`, plus an `internal mutating func markCompleted()`
  on `StudyItem` (required because `isCompleted` is `private(set)`; not
  visible outside the module).
- Agent correction: it had described `Int.max` minutes as "billions of
  years"; it is about 17.5 trillion years.
- Final checks: exact `swift test` passes; public declarations compared with
  the template commit `aca442f` are identical apart from the two
  `public init(from:)` `Decodable` implementations;
  `StudyPlannerPublicTests.swift` has no diff.

### Accepted/rejected/revised decision

Here, the solution was even more obvious; a simple option was chosen that covers the majority of use cases.

### Verification command/result

- Red: `swift test --filter StudyPlanQueriesAndCompletionTests` — crash at
  `Implement completion mutation`.
- Green: `swift test` — 47 tests, 0 failures, exit code 0 (7 validation,
  14 Codable, 12 duplicates/ordering, 11 queries/completion, 3 starter).

### Artifact links

- [artifacts/task4-red.txt](artifacts/task4-red.txt)
- [artifacts/swift-test-full.txt](artifacts/swift-test-full.txt)

---

## Entry 6 — Bonus: `importMerging(_:)`

### Tool/agent task

Asked the agent to list the open decisions for the bonus with options, and
then to implement it test-first according to R-12 A (full replacement,
including `isCompleted`), R-13 B (new IDs ordered with
`localizedStandardCompare`), R-14 B (local copy, single assignment at the
end), R-15 (reject any repeated incoming ID, first repeat in detection
order) and R-16 (empty import is a no-op).

### Output reviewed

- `Tests/StudyPlannerTests/StudyPlanImportMergingTests.swift` — 11 tests:
  replace in place + append new in ID order (`[c✓, a, e]` + `[d, a′, b]` →
  `[c✓, a′, e, b, d]`), full replacement including completion, positions from
  the plan not the import, numeric and case-insensitive new-ID order, import
  into an empty plan, empty import, duplicate incoming IDs (first repeat
  reported, plan unchanged), identical duplicates rejected, failed import
  applies neither replacements nor appends, existing ID is a replacement not
  a duplicate, merged plan works with queries and completion.
- `Sources/StudyPlanner/StudyPlanner.swift` — body of `importMerging(_:)`
  (reuses `firstDuplicateID(in:)`, `id → index` dictionary, sorted new items,
  `self = try StudyPlan(items: merged)` as the only mutation) and a private
  `isIDOrderedBefore` helper with a `<` fallback for `.orderedSame`.
- R-13 differs from the agent's recommendation (`<`). The agent recorded the
  locale risk in `PLAN.md` and checked with a local script that the IDs used
  in the tests sort identically in en_US, uk_UA, da_DK, de_DE, tr_TR, ja_JP
  and sv_SE.
- Final checks: public declarations identical to the template apart from the
  two `public init(from:)`; starter tests and fixture unchanged; no
  `fatalError` stubs left.

### Accepted/rejected/revised decision

The bonus task is indeed more complex to implement than the other parts; however, I thoroughly analyzed all architectural options and their implementations, which helped me complete the task with a solid understanding. Additionally, two earlier decisions carried over to `importMerging` unchanged. R-9 (where items retain insertion order, and title-then-ID sorting applies only to `items(in:)`) ensures stable "current positions" in the plan, allowing existing items to be replaced in place and new ones appended at the end without violating the sorting invariant. R-7 A (identifying the first occurrence based on detection order) was implemented via a dedicated helper function, `firstDuplicateID`; this helper is reused without modification for incoming duplicates, ensuring consistent duplicate reporting across both initialization and `importMerging`.

### Verification command/result

- Red: `swift test --filter StudyPlanImportMergingTests` — crash at
  `Implement optional bonus`.
- Green: `swift test` — 58 tests, 0 failures, exit code 0 (7 validation,
  14 Codable, 12 duplicates/ordering, 11 queries/completion, 11 import
  merging, 3 starter).

### Artifact links

- [artifacts/bonus-red.txt](artifacts/bonus-red.txt)
- [artifacts/swift-test-final.txt](artifacts/swift-test-final.txt)
