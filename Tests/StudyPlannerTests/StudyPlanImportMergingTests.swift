import XCTest
@testable import StudyPlanner

final class StudyPlanImportMergingTests: XCTestCase {
    // MARK: Replace and append

    func testImportReplacesExistingInPlaceAndAppendsNewInIDOrder() throws {
        var plan = try StudyPlan(items: [
            item("c", "C", isCompleted: true),
            item("a", "A"),
            item("e", "E"),
        ])
        let updatedA = item("a", "A updated", minutes: 99)

        try plan.importMerging([item("d", "D"), updatedA, item("b", "B")])

        XCTAssertEqual(plan.items.map(\.id), ["c", "a", "e", "b", "d"])
        XCTAssertEqual(plan.items[1], updatedA)
        XCTAssertTrue(plan.items[0].isCompleted)
    }

    func testReplacementIsFullIncludingCompletionStatus() throws {
        var plan = try StudyPlan(items: [item("a", "A", isCompleted: true)])
        let imported = item("a", "A again", isCompleted: false)

        try plan.importMerging([imported])

        XCTAssertEqual(plan.items, [imported])
        XCTAssertFalse(plan.items[0].isCompleted)
    }

    func testReplacementPositionsComeFromPlanNotFromImportOrder() throws {
        var plan = try StudyPlan(items: [item("c", "C"), item("a", "A"), item("e", "E")])

        try plan.importMerging([item("e", "E2"), item("a", "A2")])

        XCTAssertEqual(plan.items.map(\.id), ["c", "a", "e"])
        XCTAssertEqual(plan.items.map(\.title), ["C", "A2", "E2"])
    }

    func testNewIDsAreOrderedNumericallyAndCaseInsensitively() throws {
        var plan = try StudyPlan(items: [item("existing", "X")])

        try plan.importMerging([
            item("item-10", "T"), item("b", "T"), item("item-2", "T"),
            item("C", "T"), item("item-1", "T"), item("a", "T"),
        ])

        XCTAssertEqual(
            plan.items.map(\.id),
            ["existing", "a", "b", "C", "item-1", "item-2", "item-10"]
        )
    }

    func testImportIntoEmptyPlanOrdersAllByID() throws {
        var plan = try StudyPlan(items: [])

        try plan.importMerging([item("d", "D"), item("b", "B")])

        XCTAssertEqual(plan.items.map(\.id), ["b", "d"])
    }

    func testEmptyImportChangesNothing() throws {
        var plan = try StudyPlan(items: [item("b", "B"), item("a", "A", isCompleted: true)])
        let original = plan

        XCTAssertNoThrow(try plan.importMerging([]))

        XCTAssertEqual(plan, original)
    }

    // MARK: Duplicates and atomicity

    func testDuplicateIncomingIDsThrowFirstRepeatAndLeavePlanUnchanged() throws {
        var plan = try StudyPlan(items: [item("a", "A")])
        let original = plan

        XCTAssertThrowsError(
            try plan.importMerging([item("x", "X"), item("n", "N"), item("n", "N2"), item("x", "X2")])
        ) { error in
            XCTAssertEqual(error as? StudyPlanError, .duplicateID("n"))
        }
        XCTAssertEqual(plan, original)
    }

    func testIdenticalDuplicateIncomingItemsAreRejected() throws {
        var plan = try StudyPlan(items: [])
        let same = item("a", "A")

        XCTAssertThrowsError(try plan.importMerging([same, same])) { error in
            XCTAssertEqual(error as? StudyPlanError, .duplicateID("a"))
        }
        XCTAssertEqual(plan.items, [])
    }

    func testFailedImportDoesNotApplyReplacementsOrAppends() throws {
        var plan = try StudyPlan(items: [item("a", "A"), item("b", "B")])
        let original = plan

        // "a" would be replaced and "new" appended, but the repeated "new" makes the import fail.
        XCTAssertThrowsError(
            try plan.importMerging([item("a", "A changed"), item("new", "N"), item("new", "N2")])
        ) { error in
            XCTAssertEqual(error as? StudyPlanError, .duplicateID("new"))
        }
        XCTAssertEqual(plan, original)
    }

    func testExistingIDInImportIsReplacementNotDuplicate() throws {
        var plan = try StudyPlan(items: [item("a", "A")])

        XCTAssertNoThrow(try plan.importMerging([item("a", "A2")]))

        XCTAssertEqual(plan.items.map(\.title), ["A2"])
    }

    // MARK: Merged plan behavior

    func testMergedPlanWorksWithQueriesAndCompletion() throws {
        var plan = try StudyPlan.decode(from: fixtureData())

        try plan.importMerging([
            item("planner-milestone", "Build study planner milestone", minutes: 60, category: .project),
            item("arrays-drill", "Arrays drill", minutes: 15, category: .practice),
        ])
        try plan.markCompleted(id: "arrays-drill")

        XCTAssertEqual(
            plan.items.map(\.id),
            ["swift-chapter-1", "collections-drill", "planner-milestone", "arrays-drill"]
        )
        XCTAssertEqual(plan.incompleteMinutes(), 45 + 60)
        XCTAssertEqual(plan.items(in: .practice).map(\.id), ["arrays-drill", "collections-drill"])
    }

    // MARK: Helpers

    private func item(
        _ id: String,
        _ title: String,
        minutes: Int = 10,
        category: StudyCategory = .reading,
        isCompleted: Bool = false
    ) -> StudyItem {
        // Values here are always valid; a failure is a test bug.
        try! StudyItem(
            id: id,
            title: title,
            estimatedMinutes: minutes,
            category: category,
            isCompleted: isCompleted
        )
    }

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "study-items", withExtension: "json", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }
}
