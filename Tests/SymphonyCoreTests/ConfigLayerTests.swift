import Foundation
import XCTest
@testable import SymphonyCore

final class ConfigLayerTests: XCTestCase {
    func test_configLayer_whenValuesAreMissing_returnsDefaults() {
        // Arrange
        let definition = WorkflowDefinition(config: [:], prompt_template: "Prompt")

        // Act
        let configLayer = ConfigLayer(definition: definition)

        // Assert
        XCTAssertEqual(configLayer.pollIntervalMs, 30_000)
        XCTAssertEqual(configLayer.workspaceRoot, "/symphony_workspaces")
        XCTAssertEqual(configLayer.activeStates, ["todo", "in progress"])
        XCTAssertEqual(configLayer.terminalStates, ["closed", "cancelled", "canceled", "duplicate", "done"])
        XCTAssertEqual(configLayer.maxConcurrentAgents, 10)
        XCTAssertEqual(configLayer.maxConcurrentAgentsByState, [:])
        XCTAssertEqual(configLayer.maxRetryBackoffMs, 300_000)
        XCTAssertEqual(configLayer.agentCommand, "codex app-server")
        XCTAssertEqual(configLayer.turnTimeoutMs, 3_600_000)
        XCTAssertEqual(configLayer.stallTimeoutMs, 300_000)
        XCTAssertEqual(configLayer.readTimeoutMs, 5_000)
        XCTAssertEqual(configLayer.hookTimeoutMs, 60_000)
    }

    func test_configLayer_whenValuesAreConfigured_returnsTypedValues() {
        // Arrange
        let definition = WorkflowDefinition(
            config: [
                "pollIntervalMs": "1000",
                "workspaceRoot": "/tmp/workspaces",
                "activeStates": ["Todo", "In Progress"],
                "terminalStates": "Done, Canceled",
                "maxConcurrentAgents": "4",
                "maxConcurrentAgentsByState": [
                    "Todo": 2,
                    "IN PROGRESS": "3",
                    "done": "invalid",
                    "canceled": true,
                ],
                "maxRetryBackoffMs": 120_000,
                "agentCommand": "kai agent",
                "turnTimeoutMs": 9_000,
                "stallTimeoutMs": 8_000,
                "readTimeoutMs": 7_000,
                "hookTimeoutMs": 6_000,
            ],
            prompt_template: "Prompt"
        )

        // Act
        let configLayer = ConfigLayer(definition: definition)

        // Assert
        XCTAssertEqual(configLayer.pollIntervalMs, 1_000)
        XCTAssertEqual(configLayer.workspaceRoot, "/tmp/workspaces")
        XCTAssertEqual(configLayer.activeStates, ["Todo", "In Progress"])
        XCTAssertEqual(configLayer.terminalStates, ["Done", "Canceled"])
        XCTAssertEqual(configLayer.maxConcurrentAgents, 4)
        XCTAssertEqual(configLayer.maxConcurrentAgentsByState, [
            "todo": 2,
            "in progress": 3,
        ])
        XCTAssertEqual(configLayer.maxRetryBackoffMs, 120_000)
        XCTAssertEqual(configLayer.agentCommand, "kai agent")
        XCTAssertEqual(configLayer.turnTimeoutMs, 9_000)
        XCTAssertEqual(configLayer.stallTimeoutMs, 8_000)
        XCTAssertEqual(configLayer.readTimeoutMs, 7_000)
        XCTAssertEqual(configLayer.hookTimeoutMs, 6_000)
    }

    func test_configLayer_whenStringValueUsesEnvironmentVariable_resolvesEnvironmentValue() {
        // Arrange
        setenv("SYMPHONY_WORKSPACE_ROOT", "~/kai-workspaces", 1)
        setenv("SYMPHONY_AGENT_COMMAND", "custom-agent", 1)
        defer {
            unsetenv("SYMPHONY_WORKSPACE_ROOT")
            unsetenv("SYMPHONY_AGENT_COMMAND")
        }
        let definition = WorkflowDefinition(
            config: [
                "workspaceRoot": "$SYMPHONY_WORKSPACE_ROOT",
                "agentCommand": "$SYMPHONY_AGENT_COMMAND",
            ],
            prompt_template: "Prompt"
        )

        // Act
        let configLayer = ConfigLayer(definition: definition)

        // Assert
        XCTAssertTrue(configLayer.workspaceRoot.hasSuffix("/kai-workspaces"))
        XCTAssertFalse(configLayer.workspaceRoot.hasPrefix("~"))
        XCTAssertEqual(configLayer.agentCommand, "custom-agent")
    }

    func test_configLayer_whenWorkflowUsesNestedSections_returnsRuntimeValues() {
        // Arrange
        let definition = WorkflowDefinition(
            config: [
                "tracker": [
                    "kind": "linear",
                    "project_slug": "daniel-bernal",
                    "api_key": "$LINEAR_API_KEY",
                ],
                "polling": [
                    "interval_ms": 45_000,
                ],
                "workspace": [
                    "root": "~/symphony_workspaces",
                ],
                "hooks": [
                    "after_create": "git clone repo .",
                    "before_run": "echo before-run",
                    "after_run": "echo after-run",
                    "before_remove": "echo before-remove",
                ],
                "agent": [
                    "max_concurrent_agents": 3,
                ],
                "codex": [
                    "command": "codex app-server",
                    "turn_timeout_ms": 9_000,
                    "stall_timeout_ms": 8_000,
                ],
            ],
            prompt_template: "Prompt"
        )
        setenv("LINEAR_API_KEY", "linear-test-key", 1)
        defer { unsetenv("LINEAR_API_KEY") }

        // Act
        let configLayer = ConfigLayer(definition: definition)

        // Assert
        XCTAssertEqual(configLayer.trackerKind, "linear")
        XCTAssertEqual(configLayer.projectSlug, "daniel-bernal")
        XCTAssertEqual(configLayer.apiKey, "linear-test-key")
        XCTAssertEqual(configLayer.pollIntervalMs, 45_000)
        XCTAssertTrue(configLayer.workspaceRoot.hasSuffix("/symphony_workspaces"))
        XCTAssertEqual(configLayer.afterCreateHook, "git clone repo .")
        XCTAssertEqual(configLayer.beforeRunHook, "echo before-run")
        XCTAssertEqual(configLayer.afterRunHook, "echo after-run")
        XCTAssertEqual(configLayer.beforeRemoveHook, "echo before-remove")
        XCTAssertEqual(configLayer.maxConcurrentAgents, 3)
        XCTAssertEqual(configLayer.agentCommand, "codex app-server")
        XCTAssertEqual(configLayer.turnTimeoutMs, 9_000)
        XCTAssertEqual(configLayer.stallTimeoutMs, 8_000)
    }
}
