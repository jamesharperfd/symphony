import Foundation
@testable import SymphonyCore

final class MockAgentRunner: AgentRunning {
    var runHandler: ((Issue, Workspace, String) -> AsyncThrowingStream<AgentEvent, Error>)?
    var activeContinuations: [String: AsyncThrowingStream<AgentEvent, Error>.Continuation] = [:]
    var canceledIssueIDs: [String] = []
    private(set) var receivedIssues: [Issue] = []
    private(set) var receivedWorkspaces: [Workspace] = []
    private(set) var receivedPromptTemplates: [String] = []

    func run(
        issue: Issue,
        workspace: Workspace,
        promptTemplate: String
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        receivedIssues.append(issue)
        receivedWorkspaces.append(workspace)
        receivedPromptTemplates.append(promptTemplate)

        if let runHandler {
            return runHandler(issue, workspace, promptTemplate)
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(.completed)
            continuation.finish()
        }
    }
}
