import Foundation

public struct RetryEntry: Codable, Equatable {
    public let issueId: String
    public let identifier: String
    public let attempt: Int
    public let dueAtMs: Int
    public let error: String?

    public init(issueId: String, identifier: String, attempt: Int, dueAtMs: Int, error: String?) {
        self.issueId = issueId
        self.identifier = identifier
        self.attempt = attempt
        self.dueAtMs = dueAtMs
        self.error = error
    }
}
