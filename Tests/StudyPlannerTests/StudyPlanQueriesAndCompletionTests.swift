import XCTest
@testable import StudyPlanner

final class StudyPlanQueriesAndCompletionTests: XCTestCase {
    // MARK: Category queries

    func testItemsInCategoryReturnsOnlyThatCategory() throws {
        let plan = try StudyPlan.decode(from: fixtureData())

        XCTAssertEqual(plan.items(in: .reading).map(\.id), ["swift-chapter-1"])
        XCTAssertEqual(plan.items(in: .practice).map(\.id), ["collections-drill"])
        XCTAssertEqual(plan.items(in: .project).map(\.id), ["planner-milestone"])
    }

    func testItemsInCategoryWithoutItemsIsEmpty() throws {
        let plan = try StudyPlan(items: [item("a", minutes: 10, category: .reading)])

        XCTAssertEqual(plan.items(in: .project), [])
    }

    func testEmptyPlanQueriesReturnEmptyAndZero() throws {
        let plan = try StudyPlan(items: [])

        for category in StudyCategory.allCases {
            XCTAssertEqual(plan.items(in: category), [], "\(category)")
        }
        XCTAssertEqual(plan.incompleteMinutes(), 0)
    }

    // MARK: Incomplete minutes

    func testIncompleteMinutesSumsOnlyIncompleteItems() throws {
        let plan = try StudyPlan.decode(from: fixtureData())

        XCTAssertEqual(plan.incompleteMinutes(), 45 + 90)
    }

    func testIncompleteMinutesIsZeroWhenEverythingIsCompleted() throws {
        let plan = try StudyPlan(items: [
            item("a", minutes: 10, category: .reading, isCompleted: true),
            item("b", minutes: 20, category: .project, isCompleted: true),
        ])

        XCTAssertEqual(plan.incompleteMinutes(), 0)
    }

    // MARK: Completion

    func testMarkCompletedChangesOnlyThatItem() throws {
        var plan = try StudyPlan(items: [
            item("a", minutes: 10, category: .reading),
            item("b", minutes: 20, category: .practice),
            item("c", minutes: 30, category: .project),
        ])

        try plan.markCompleted(id: "b")

        XCTAssertEqual(plan.items.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(plan.items.map(\.isCompleted), [false, true, false])
        XCTAssertEqual(plan.items[1].title, "Item b")
        XCTAssertEqual(plan.items[1].estimatedMinutes, 20)
        XCTAssertEqual(plan.incompleteMinutes(), 40)
    }

    func testMarkCompletedWithUnknownIDThrowsAndLeavesPlanUnchanged() throws {
        var plan = try StudyPlan(items: [item("a", minutes: 10, category: .reading)])
        let original = plan

        for unknownID in ["nope", "A", " a", ""] {
            XCTAssertThrowsError(try plan.markCompleted(id: unknownID), unknownID) { error in
                XCTAssertEqual(error as? StudyPlanError, .unknownID(unknownID))
            }
            XCTAssertEqual(plan, original, unknownID)
        }
    }

    func testMarkCompletedOnEmptyPlanThrowsUnknownID() throws {
        var plan = try StudyPlan(items: [])

        XCTAssertThrowsError(try plan.markCompleted(id: "a")) { error in
            XCTAssertEqual(error as? StudyPlanError, .unknownID("a"))
        }
    }

    func testMarkCompletedIsIdempotent() throws {
        var plan = try StudyPlan(items: [
            item("a", minutes: 10, category: .reading),
            item("b", minutes: 20, category: .reading),
        ])

        try plan.markCompleted(id: "a")
        let afterFirst = plan
        XCTAssertNoThrow(try plan.markCompleted(id: "a"))

        XCTAssertEqual(plan, afterFirst)
        XCTAssertEqual(plan.incompleteMinutes(), 20)
    }

    func testMarkCompletedOnItemAlreadyCompletedInFixture() throws {
        var plan = try StudyPlan.decode(from: fixtureData())
        let original = plan

        XCTAssertNoThrow(try plan.markCompleted(id: "collections-drill"))

        XCTAssertEqual(plan, original)
        XCTAssertEqual(plan.incompleteMinutes(), 135)
    }

    func testCompletionIsVisibleInQueriesAndEncodedJSON() throws {
        var plan = try StudyPlan.decode(from: fixtureData())

        try plan.markCompleted(id: "planner-milestone")

        XCTAssertEqual(plan.incompleteMinutes(), 45)
        XCTAssertEqual(plan.items(in: .project).map(\.isCompleted), [true])

        let decoded = try JSONDecoder().decode(StudyPlan.self, from: JSONEncoder().encode(plan))
        XCTAssertEqual(decoded, plan)
    }

    // MARK: Helpers

    private func item(
        _ id: String,
        minutes: Int,
        category: StudyCategory,
        isCompleted: Bool = false
    ) -> StudyItem {
        // Values here are always valid; a failure is a test bug.
        try! StudyItem(
            id: id,
            title: "Item \(id)",
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
