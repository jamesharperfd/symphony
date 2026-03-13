import Foundation

public protocol LinearClienting {
    func fetchActiveIssues(teamSlug: String, states: [String]) async throws -> [Issue]
    func fetchIssueStates(ids: [String]) async throws -> [String: String]
}
