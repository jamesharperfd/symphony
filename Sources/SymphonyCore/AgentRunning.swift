import Foundation

public protocol AgentRunning {
    func run(
        issue: Issue,
        workspace: Workspace,
        promptTemplate: String
    ) -> AsyncThrowingStream<AgentEvent, Error>
}
