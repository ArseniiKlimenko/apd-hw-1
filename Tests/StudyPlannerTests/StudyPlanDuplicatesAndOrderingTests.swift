import XCTest
@testable import StudyPlanner

final class StudyPlanDuplicatesAndOrderingTests: XCTestCase {
    // MARK: Duplicate IDs

    func testDuplicateIDThrowsDuplicateID() throws {
        let items = try makeItems(ids: ["a", "b", "a"])

        assertThrows(.duplicateID("a")) { try StudyPlan(items: items) }
    }

    func testFirstRepeatInDetectionOrderIsReported() throws {
        let cases: [(ids: [String], expected: String)] = [
            (["a", "b", "b", "a"], "b"),
            (["b", "a", "a", "b"], "a"),
            (["c", "a", "c", "a"], "c"),
            (["x", "y", "z", "z", "z"], "z"),
        ]

        for (ids, expected) in cases {
            let items = try makeItems(ids: ids)
            assertThrows(.duplicateID(expected), "ids: \(ids)") { try StudyPlan(items: items) }
        }
    }

    func testIDsDifferingInCaseOrWhitespaceAreNotDuplicates() throws {
        let plan = try StudyPlan(items: makeItems(ids: ["a", "A", " a", "a "]))

        XCTAssertEqual(plan.items.map(\.id), ["a", "A", " a", "a "])
    }

    func testCanonicallyEquivalentIDsAreDuplicates() throws {
        let precomposed = "caf\u{E9}"
        let decomposed = "cafe\u{301}"

        let items = try makeItems(ids: [precomposed, decomposed])

        assertThrows(.duplicateID(decomposed)) { try StudyPlan(items: items) }
    }

    func testDuplicateInKeyedJSONThrowsDuplicateID() {
        let json = #"""
        {"items": [
            {"id": "a", "title": "A", "estimatedMinutes": 10, "category": "reading"},
            {"id": "b", "title": "B", "estimatedMinutes": 10, "category": "reading"},
            {"id": "a", "title": "C", "estimatedMinutes": 10, "category": "practice"}
        ]}
        """#

        assertThrows(.duplicateID("a")) {
            try JSONDecoder().decode(StudyPlan.self, from: Data(json.utf8))
        }
    }

    func testDuplicateInTopLevelArrayThrowsDuplicateID() {
        let json = #"""
        [
            {"id": "a", "title": "A", "estimatedMinutes": 10, "category": "reading"},
            {"id": "a", "title": "B", "estimatedMinutes": 20, "category": "project"}
        ]
        """#

        assertThrows(.duplicateID("a")) { try StudyPlan.decode(from: Data(json.utf8)) }
    }

    // MARK: Ordering

    func testItemsKeepInsertionOrder() throws {
        let plan = try StudyPlan(items: [
            item("r2", "Swift", .reading),
            item("p1", "Planner", .project),
            item("r1", "Arrays", .reading),
        ])

        XCTAssertEqual(plan.items.map(\.id), ["r2", "p1", "r1"])
    }

    func testItemsInCategoryAreOrderedByTitle() throws {
        let plan = try StudyPlan(items: [
            item("r1", "Swift", .reading),
            item("p1", "Build", .project),
            item("r2", "Arrays", .reading),
            item("r3", "Planner", .reading),
        ])

        XCTAssertEqual(plan.items(in: .reading).map(\.title), ["Arrays", "Planner", "Swift"])
    }

    func testEqualTitlesAreOrderedByID() throws {
        let plan = try StudyPlan(items: [
            item("c", "Swift", .practice),
            item("a", "Swift", .practice),
            item("b", "Swift", .practice),
        ])

        XCTAssertEqual(plan.items(in: .practice).map(\.id), ["a", "b", "c"])
    }

    func testTitleOrderingIgnoresCase() throws {
        let plan = try StudyPlan(items: [
            item("1", "Cherry", .reading),
            item("2", "banana", .reading),
            item("3", "Apple", .reading),
        ])

        XCTAssertEqual(plan.items(in: .reading).map(\.title), ["Apple", "banana", "Cherry"])
    }

    func testTitleOrderingIsNumericAware() throws {
        let plan = try StudyPlan(items: [
            item("1", "Item 10", .practice),
            item("2", "Item 2", .practice),
            item("3", "Item 1", .practice),
        ])

        XCTAssertEqual(plan.items(in: .practice).map(\.title), ["Item 1", "Item 2", "Item 10"])
    }

    func testCategoryOrderDoesNotDependOnInsertionOrder() throws {
        let items = [
            item("b", "Swift", .reading),
            item("x", "Arrays", .reading),
            item("a", "Swift", .reading),
            item("p", "Build", .project),
        ]

        let expected = ["x", "a", "b"]
        for permutation in [items, items.reversed(), [items[2], items[0], items[3], items[1]]] {
            let plan = try StudyPlan(items: permutation)
            XCTAssertEqual(plan.items(in: .reading).map(\.id), expected)
        }
    }

    // MARK: Helpers

    private func item(_ id: String, _ title: String, _ category: StudyCategory) -> StudyItem {
        // Titles here are always valid; a failure is a test bug.
        try! StudyItem(id: id, title: title, estimatedMinutes: 10, category: category)
    }

    private func makeItems(ids: [String]) throws -> [StudyItem] {
        try ids.map { try StudyItem(id: $0, title: "Item \($0)", estimatedMinutes: 10, category: .reading) }
    }

    private func assertThrows(
        _ expected: StudyPlanError,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ expression: () throws -> some Any
    ) {
        XCTAssertThrowsError(try expression(), message, file: file, line: line) { error in
            XCTAssertEqual(error as? StudyPlanError, expected, "\(message) \(error)", file: file, line: line)
        }
    }
}
