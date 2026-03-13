import Foundation

public struct ConfigLayer {
    private let workflowConfig: WorkflowConfig
    public let promptTemplate: String

    public init(definition: WorkflowDefinition) {
        self.workflowConfig = WorkflowConfig(config: definition.config)
        self.promptTemplate = definition.prompt_template
    }

    public var trackerKind: String? { workflowConfig.trackerKind }
    public var projectSlug: String? { workflowConfig.projectSlug }
    public var apiKey: String? { workflowConfig.apiKey }
    public var pollIntervalMs: Int { workflowConfig.pollIntervalMs }
    public var workspaceRoot: String { workflowConfig.workspaceRoot }
    public var afterCreateHook: String? { workflowConfig.afterCreateHook }
    public var beforeRunHook: String? { workflowConfig.beforeRunHook }
    public var afterRunHook: String? { workflowConfig.afterRunHook }
    public var beforeRemoveHook: String? { workflowConfig.beforeRemoveHook }
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
