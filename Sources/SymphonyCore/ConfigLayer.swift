import Foundation

public struct ConfigLayer {
    private let workflowConfig: WorkflowConfig

    public init(definition: WorkflowDefinition) {
        self.workflowConfig = WorkflowConfig(config: definition.config)
    }

    public var pollIntervalMs: Int { workflowConfig.pollIntervalMs }
    public var workspaceRoot: String { workflowConfig.workspaceRoot }
    public var activeStates: [String] { workflowConfig.activeStates }
    public var terminalStates: [String] { workflowConfig.terminalStates }
    public var maxConcurrentAgents: Int { workflowConfig.maxConcurrentAgents }
    public var maxConcurrentAgentsByState: [String: Int] { workflowConfig.maxConcurrentAgentsByState }
    public var maxRetryBackoffMs: Int { workflowConfig.maxRetryBackoffMs }
    public var agentCommand: String { workflowConfig.agentCommand }
    public var turnTimeoutMs: Int { workflowConfig.turnTimeoutMs }
    public var stallTimeoutMs: Int { workflowConfig.stallTimeoutMs }
    public var readTimeoutMs: Int { workflowConfig.readTimeoutMs }
    public var hookTimeoutMs: Int { workflowConfig.hookTimeoutMs }
}
