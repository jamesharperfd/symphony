import Foundation
@testable import SymphonyCore

final class MockWorkspaceManager: WorkspaceManaging {
    var workspacesByIdentifier: [String: Workspace] = [:]
    private(set) var requestedIssues: [Issue] = []
    private(set) var hooks: [(script: String, workspace: Workspace, timeoutMs: Int)] = []
    private(set) var removedIdentifiers: [String] = []

    func workspace(for issue: Issue) throws -> Workspace {
        requestedIssues.append(issue)
        if let workspace = workspacesByIdentifier[issue.identifier] {
            return workspace
        }

        return Workspace(
            path: "/tmp/\(issue.identifier)",
            workspaceKey: issue.identifier,
            createdNow: true
        )
    }

    func runHook(_ script: String, in workspace: Workspace, timeoutMs: Int) throws {
        hooks.append((script, workspace, timeoutMs))
    }

    func removeWorkspace(for identifier: String) throws {
        removedIdentifiers.append(identifier)
    }
}
