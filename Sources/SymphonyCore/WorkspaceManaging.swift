import Foundation

public protocol WorkspaceManaging {
    func workspace(for issue: Issue) throws -> Workspace
    func runHook(_ script: String, in workspace: Workspace, timeoutMs: Int) throws
    func removeWorkspace(for identifier: String) throws
}
