import Foundation

public struct Issue: Codable, Equatable {
    public let id: String
    public let identifier: String
    public let title: String
    public let description: String?
    public let priority: Int?
    public let state: String
    public let branch_name: String?
    public let url: String?
    public let labels: [String]
    public let blocked_by: [BlockerRef]
    public let created_at: Date?
    public let updated_at: Date?

    public init(
        id: String,
        identifier: String,
        title: String,
        description: String?,
        priority: Int?,
        state: String,
        branch_name: String?,
        url: String?,
        labels: [String],
        blocked_by: [BlockerRef],
        created_at: Date?,
        updated_at: Date?
    ) {
        self.id = id
        self.identifier = identifier
        self.title = title
        self.description = description
        self.priority = priority
        self.state = state
        self.branch_name = branch_name
        self.url = url
        self.labels = labels
        self.blocked_by = blocked_by
        self.created_at = created_at
        self.updated_at = updated_at
    }
}
