import XCTest
@testable import StudyPlanner

final class StudyItemValidationTests: XCTestCase {
    func testValidItemStoresAllValuesAsGiven() throws {
        let item = try StudyItem(
            id: "proj-1",
            title: "  Build planner  \n",
            estimatedMinutes: 90,
            category: .project,
            isCompleted: true
        )

        XCTAssertEqual(item.id, "proj-1")
        XCTAssertEqual(item.title, "  Build planner  \n")
        XCTAssertEqual(item.estimatedMinutes, 90)
        XCTAssertEqual(item.category, .project)
        XCTAssertTrue(item.isCompleted)
    }

    func testEmptyTitleThrowsBlankTitle() {
        assertThrows(.blankTitle) {
            try StudyItem(id: "x", title: "", estimatedMinutes: 10, category: .reading)
        }
    }

    func testWhitespaceOnlyTitlesThrowBlankTitle() {
        let blankTitles = [" ", "\t", "\n", "\r\n", " \t\n ", "\u{00A0}", "\u{3000}"]

        for title in blankTitles {
            assertThrows(.blankTitle, "title: \(title.debugDescription)") {
                try StudyItem(id: "x", title: title, estimatedMinutes: 10, category: .reading)
            }
        }
    }

    func testNonPositiveMinutesThrow() {
        for minutes in [0, -1, Int.min] {
            assertThrows(.nonPositiveEstimatedMinutes, "minutes: \(minutes)") {
                try StudyItem(id: "x", title: "Read", estimatedMinutes: minutes, category: .reading)
            }
        }
    }

    func testOneMinuteIsAccepted() throws {
        let item = try StudyItem(id: "x", title: "Read", estimatedMinutes: 1, category: .reading)

        XCTAssertEqual(item.estimatedMinutes, 1)
    }

    func testBlankTitleTakesPrecedenceOverNonPositiveMinutes() {
        assertThrows(.blankTitle) {
            try StudyItem(id: "x", title: "  ", estimatedMinutes: 0, category: .practice)
        }
    }

    func testEmptyIDIsAccepted() throws {
        let item = try StudyItem(id: "", title: "Read", estimatedMinutes: 5, category: .reading)

        XCTAssertEqual(item.id, "")
    }

    private func assertThrows(
        _ expected: StudyPlanError,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ expression: () throws -> some Any
    ) {
        XCTAssertThrowsError(try expression(), message, file: file, line: line) { error in
            XCTAssertEqual(error as? StudyPlanError, expected, message, file: file, line: line)
        }
    }
}
