import XCTest
@testable import StudyPlanner

final class StudyPlanCodableTests: XCTestCase {
    // MARK: StudyItem decoding

    func testDecodingItemWithBlankTitleThrowsBlankTitle() {
        let json = #"{"id": "a", "title": "  ", "estimatedMinutes": 10, "category": "reading", "isCompleted": false}"#

        assertThrows(.blankTitle) { try decodeItem(json) }
    }

    func testDecodingItemWithNonPositiveMinutesThrows() {
        let json = #"{"id": "a", "title": "Read", "estimatedMinutes": 0, "category": "reading", "isCompleted": false}"#

        assertThrows(.nonPositiveEstimatedMinutes) { try decodeItem(json) }
    }

    func testDecodingItemWithoutIsCompletedDefaultsToFalse() throws {
        let json = #"{"id": "a", "title": "Read", "estimatedMinutes": 10, "category": "reading"}"#

        let item = try decodeItem(json)

        XCTAssertFalse(item.isCompleted)
    }

    func testDecodingItemWithMissingRequiredKeyThrowsKeyNotFound() {
        let json = #"{"id": "a", "estimatedMinutes": 10, "category": "reading"}"#

        XCTAssertThrowsError(try decodeItem(json)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("Expected keyNotFound, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "title")
        }
    }

    func testDecodingItemWithWrongValueTypesThrowsDecodingError() {
        let invalidItems = [
            #"{"id": "a", "title": "Read", "estimatedMinutes": "30", "category": "reading"}"#,
            #"{"id": "a", "title": "Read", "estimatedMinutes": 30.5, "category": "reading"}"#,
            #"{"id": "a", "title": "Read", "estimatedMinutes": 30, "category": "video"}"#,
        ]

        for json in invalidItems {
            XCTAssertThrowsError(try decodeItem(json), json) { error in
                XCTAssertTrue(error is DecodingError, "\(json): \(error)")
            }
        }
    }

    func testItemRoundTripsThroughJSON() throws {
        let item = try StudyItem(
            id: "p1",
            title: "  Build planner ",
            estimatedMinutes: 90,
            category: .project,
            isCompleted: true
        )

        let decoded = try JSONDecoder().decode(StudyItem.self, from: JSONEncoder().encode(item))

        XCTAssertEqual(decoded, item)
    }

    // MARK: StudyPlan keyed decoding

    func testKeyedPlanDecodesItemsInOrder() throws {
        let json = #"""
        {"items": [
            {"id": "b", "title": "B", "estimatedMinutes": 20, "category": "practice", "isCompleted": true},
            {"id": "a", "title": "A", "estimatedMinutes": 10, "category": "reading"}
        ]}
        """#

        let plan = try JSONDecoder().decode(StudyPlan.self, from: Data(json.utf8))

        XCTAssertEqual(plan.items.map(\.id), ["b", "a"])
        XCTAssertEqual(plan.items.map(\.isCompleted), [true, false])
    }

    func testKeyedPlanPropagatesItemValidationError() {
        let json = #"""
        {"items": [
            {"id": "a", "title": "A", "estimatedMinutes": 10, "category": "reading"},
            {"id": "b", "title": "", "estimatedMinutes": 10, "category": "reading"}
        ]}
        """#

        assertThrows(.blankTitle) {
            try JSONDecoder().decode(StudyPlan.self, from: Data(json.utf8))
        }
    }

    func testPlanRoundTripsThroughKeyedJSON() throws {
        let plan = try StudyPlan(items: [
            StudyItem(id: "a", title: "A", estimatedMinutes: 10, category: .reading),
            StudyItem(id: "b", title: "B", estimatedMinutes: 20, category: .project, isCompleted: true),
        ])

        let data = try JSONEncoder().encode(plan)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(Array(object.keys), ["items"])
        XCTAssertEqual(try JSONDecoder().decode(StudyPlan.self, from: data), plan)
    }

    // MARK: StudyPlan.decode(from:) — top-level array

    func testDecodeFromFixtureReadsAllItemsInFileOrder() throws {
        let plan = try StudyPlan.decode(from: fixtureData())

        XCTAssertEqual(
            plan.items.map(\.id),
            ["swift-chapter-1", "collections-drill", "planner-milestone"]
        )
        XCTAssertEqual(plan.items.map(\.category), [.reading, .practice, .project])
        XCTAssertEqual(plan.items.map(\.estimatedMinutes), [45, 30, 90])
        XCTAssertEqual(plan.items.map(\.isCompleted), [false, true, false])
    }

    func testDecodeFromEmptyArrayGivesEmptyPlan() throws {
        let plan = try StudyPlan.decode(from: Data("[]".utf8))

        XCTAssertTrue(plan.items.isEmpty)
    }

    func testDecodeFromPropagatesItemValidationError() {
        let json = #"""
        [
            {"id": "a", "title": "A", "estimatedMinutes": 10, "category": "reading"},
            {"id": "b", "title": "B", "estimatedMinutes": -5, "category": "reading"}
        ]
        """#

        assertThrows(.nonPositiveEstimatedMinutes) {
            try StudyPlan.decode(from: Data(json.utf8))
        }
    }

    func testDecodeFromRejectsKeyedObject() {
        let json = #"{"items": []}"#

        XCTAssertThrowsError(try StudyPlan.decode(from: Data(json.utf8))) { error in
            guard case DecodingError.typeMismatch = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
        }
    }

    func testDecodeFromRejectsMalformedJSON() {
        XCTAssertThrowsError(try StudyPlan.decode(from: Data("[{".utf8))) { error in
            XCTAssertTrue(error is DecodingError, "\(error)")
        }
    }

    // MARK: Helpers

    private func decodeItem(_ json: String) throws -> StudyItem {
        try JSONDecoder().decode(StudyItem.self, from: Data(json.utf8))
    }

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "study-items", withExtension: "json", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }

    private func assertThrows(
        _ expected: StudyPlanError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ expression: () throws -> some Any
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            XCTAssertEqual(error as? StudyPlanError, expected, "\(error)", file: file, line: line)
        }
    }
}
