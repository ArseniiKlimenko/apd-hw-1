import Foundation

public enum StudyCategory: String, Codable, CaseIterable {
    case reading, practice, project
}

public enum StudyPlanError: Error, Equatable {
    case blankTitle
    case nonPositiveEstimatedMinutes
    case duplicateID(String)
    case unknownID(String)
}

public struct StudyItem: Codable, Equatable {
    public let id: String
    public let title: String
    public let estimatedMinutes: Int
    public let category: StudyCategory
    public private(set) var isCompleted: Bool

    public init(
        id: String,
        title: String,
        estimatedMinutes: Int,
        category: StudyCategory,
        isCompleted: Bool = false
    ) throws {
        // Title is checked first; it is stored as given, trimming is only for the check.
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudyPlanError.blankTitle
        }
        guard estimatedMinutes > 0 else {
            throw StudyPlanError.nonPositiveEstimatedMinutes
        }

        self.id = id
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.category = category
        self.isCompleted = isCompleted
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, estimatedMinutes, category, isCompleted
    }

    // Decoding goes through the validating initializer; its StudyPlanError propagates unchanged.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(String.self, forKey: .id),
            title: container.decode(String.self, forKey: .title),
            estimatedMinutes: container.decode(Int.self, forKey: .estimatedMinutes),
            category: container.decode(StudyCategory.self, forKey: .category),
            isCompleted: container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        )
    }

    // Internal: isCompleted stays read-only outside the module; StudyPlan.markCompleted(id:) uses this.
    mutating func markCompleted() {
        isCompleted = true
    }
}

public struct StudyPlan: Codable, Equatable {
    public private(set) var items: [StudyItem]

    public init(items: [StudyItem]) throws {
        if let duplicate = Self.firstDuplicateID(in: items) {
            throw StudyPlanError.duplicateID(duplicate)
        }
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }

    // Keyed {"items": [...]} format; every item and the plan itself are validated.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(items: container.decode([StudyItem].self, forKey: .items))
    }

    public static func decode(from data: Data) throws -> StudyPlan {
        let items = try JSONDecoder().decode([StudyItem].self, from: data)
        return try StudyPlan(items: items)
    }

    public func items(in category: StudyCategory) -> [StudyItem] {
        items
            .filter { $0.category == category }
            .sorted(by: Self.isOrderedBefore)
    }

    // Plain + traps on overflow rather than returning a wrong sum.
    public func incompleteMinutes() -> Int {
        items
            .filter { !$0.isCompleted }
            .reduce(0) { $0 + $1.estimatedMinutes }
    }

    // Unknown ID throws before any change; an already completed item stays as is.
    public mutating func markCompleted(id: String) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw StudyPlanError.unknownID(id)
        }
        items[index].markCompleted()
    }

    public mutating func importMerging(_ importedItems: [StudyItem]) throws {
        fatalError("Implement optional bonus")
    }

    // First ID that repeats an earlier one, scanning left to right.
    private static func firstDuplicateID(in items: [StudyItem]) -> String? {
        var seen = Set<String>()
        for item in items where !seen.insert(item.id).inserted {
            return item.id
        }
        return nil
    }

    // Title via localizedStandardCompare, then ID; IDs are unique, so the order is total.
    private static func isOrderedBefore(_ lhs: StudyItem, _ rhs: StudyItem) -> Bool {
        switch lhs.title.localizedStandardCompare(rhs.title) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: lhs.id < rhs.id
        }
    }
}
