import XCTest
@testable import SymphonyCore

final class WorkflowConfigTests: XCTestCase {
    func test_workflowConfig_whenValuesAreMissing_returnsDefaults() {
        let config = WorkflowConfig(config: [:])

        XCTAssertEqual(config.pollIntervalMs, 30_000)
        XCTAssertEqual(config.workspaceRoot, "/symphony_workspaces")
        XCTAssertEqual(config.activeStates, ["todo", "in progress"])
        XCTAssertEqual(config.terminalStates, ["closed", "cancelled", "canceled", "duplicate", "done"])
        XCTAssertEqual(config.maxConcurrentAgents, 10)
        XCTAssertEqual(config.maxRetryBackoffMs, 300_000)
        XCTAssertEqual(config.agentCommand, "codex app-server")
        XCTAssertEqual(config.turnTimeoutMs, 3_600_000)
        XCTAssertEqual(config.stallTimeoutMs, 300_000)
        XCTAssertEqual(config.readTimeoutMs, 5_000)
        XCTAssertEqual(config.hookTimeoutMs, 60_000)
    }

    func test_workflowConfig_whenWorkspaceRootUsesTilde_expandsHomeDirectory() {
        let config = WorkflowConfig(config: ["workspaceRoot": "~/custom"])

        XCTAssertTrue(config.workspaceRoot.hasSuffix("/custom"))
        XCTAssertFalse(config.workspaceRoot.hasPrefix("~"))
    }

    func test_workflowConfig_whenValueUsesEnvironmentVariable_resolvesValue() {
        setenv("SYMPHONY_AGENT_COMMAND", "custom-agent", 1)
        defer { unsetenv("SYMPHONY_AGENT_COMMAND") }

        let config = WorkflowConfig(config: ["agentCommand": "$SYMPHONY_AGENT_COMMAND"])

        XCTAssertEqual(config.agentCommand, "custom-agent")
    }
}
