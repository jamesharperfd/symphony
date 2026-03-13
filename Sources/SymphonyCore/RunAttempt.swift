import Foundation

public struct RunAttempt: Codable, Equatable {
    public enum Status: String, Codable {
        case pending
        case running
        case completed
        case failed
    }

    public let issueId: String
    public let issueIdentifier: String
    public let attempt: Int?
    public let workspacePath: String
    public let startedAt: Date
    public let status: Status
    public let error: String?

    public init(
        issueId: String,
        issueIdentifier: String,
        attempt: Int?,
        workspacePath: String,
        startedAt: Date,
        status: Status,
        error: String?
    ) {
        self.issueId = issueId
        self.issueIdentifier = issueIdentifier
        self.attempt = attempt
        self.workspacePath = workspacePath
        self.startedAt = startedAt
        self.status = status
        self.error = error
    }
}
