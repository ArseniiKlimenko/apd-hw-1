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
}

public struct StudyPlan: Codable, Equatable {
    public private(set) var items: [StudyItem]

    public init(items: [StudyItem]) throws {
        // TODO(task 3): reject duplicate IDs.
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
        fatalError("Implement category query")
    }

    public func incompleteMinutes() -> Int {
        fatalError("Implement incomplete-minute query")
    }

    public mutating func markCompleted(id: String) throws {
        fatalError("Implement completion mutation")
    }

    public mutating func importMerging(_ importedItems: [StudyItem]) throws {
        fatalError("Implement optional bonus")
    }
}
