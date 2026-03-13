import Foundation
@testable import SymphonyCore

final class MockLinearClient: LinearClienting {
    var activeIssues: [Issue] = []
    var issueStates: [String: String] = [:]
    private(set) var fetchActiveIssuesCalls: [(teamSlug: String, states: [String])] = []
    private(set) var fetchIssueStatesCalls: [[String]] = []

    func fetchActiveIssues(teamSlug: String, states: [String]) async throws -> [Issue] {
        fetchActiveIssuesCalls.append((teamSlug, states))
        return activeIssues
    }

    func fetchIssueStates(ids: [String]) async throws -> [String: String] {
        fetchIssueStatesCalls.append(ids)
        return issueStates
    }
}
