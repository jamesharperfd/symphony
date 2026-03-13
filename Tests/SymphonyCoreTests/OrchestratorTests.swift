import Foundation
import XCTest
@testable import SymphonyCore

final class OrchestratorTests: XCTestCase {
    func test_pollOnce_dispatchesRunnableIssue() async throws {
        // Arrange
        let issue = makeIssue(identifier: "DB-189", state: "todo", blockers: [])
        let linearClient = MockLinearClient()
        linearClient.activeIssues = [issue]
        let workspaceManager = MockWorkspaceManager()
        let agentRunner = MockAgentRunner()
        agentRunner.runHandler = { _, _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.completed)
                continuation.finish()
            }
        }
        let orchestrator = Orchestrator(
            config: makeConfig([
                "activeStates": ["todo"],
                "hooks": [
                    "before_run": "echo before-run",
                    "after_run": "echo after-run",
                ],
            ]),
            linearClient: linearClient,
            workspaceManager: workspaceManager,
            agentRunner: agentRunner
        )

        // Act
        await orchestrator.pollOnce()
        await orchestrator.stop()

        // Assert
        XCTAssertEqual(agentRunner.receivedIssues.map(\.identifier), ["DB-189"])
        XCTAssertEqual(workspaceManager.requestedIssues.map(\.identifier), ["DB-189"])
        XCTAssertEqual(workspaceManager.hooks.map(\.script), ["echo before-run", "echo after-run"])
    }

    func test_pollOnce_whenIssueHasUnresolvedBlocker_doesNotDispatch() async throws {
        // Arrange
        let blockedIssue = makeIssue(
            identifier: "DB-190",
            state: "todo",
            blockers: [BlockerRef(id: "blocker-1", identifier: "DB-100", state: "in progress")]
        )
        let linearClient = MockLinearClient()
        linearClient.activeIssues = [blockedIssue]
        let orchestrator = Orchestrator(
            config: makeConfig([:]),
            linearClient: linearClient,
            workspaceManager: MockWorkspaceManager(),
            agentRunner: MockAgentRunner()
        )

        // Act
        await orchestrator.pollOnce()
        let snapshot = await orchestrator.snapshot()
        await orchestrator.stop()

        // Assert
        XCTAssertTrue(snapshot.running.isEmpty)
        XCTAssertTrue(snapshot.claimed.isEmpty)
    }

    func test_pollOnce_respectsMaxConcurrentAgents() async throws {
        // Arrange
        let firstIssue = makeIssue(identifier: "DB-189", state: "todo", blockers: [])
        let secondIssue = makeIssue(identifier: "DB-190", state: "todo", blockers: [])
        let linearClient = MockLinearClient()
        linearClient.activeIssues = [firstIssue, secondIssue]
        let agentRunner = MockAgentRunner()
        agentRunner.runHandler = { issue, _, _ in
            AsyncThrowingStream { continuation in
                if issue.identifier == "DB-189" {
                    agentRunner.activeContinuations[issue.id] = continuation
                } else {
                    continuation.yield(.completed)
                    continuation.finish()
                }
            }
        }
        let orchestrator = Orchestrator(
            config: makeConfig(["maxConcurrentAgents": 1]),
            linearClient: linearClient,
            workspaceManager: MockWorkspaceManager(),
            agentRunner: agentRunner
        )

        // Act
        await orchestrator.pollOnce()
        agentRunner.activeContinuations[firstIssue.id]?.finish()
        await orchestrator.stop()

        // Assert
        XCTAssertEqual(agentRunner.receivedIssues.map(\.identifier), ["DB-189"])
    }

    func test_pollOnce_whenRunningIssueBecomesTerminal_cancelsAndReconcilesState() async throws {
        // Arrange
        let issue = makeIssue(identifier: "DB-189", state: "todo", blockers: [])
        let linearClient = MockLinearClient()
        linearClient.activeIssues = [issue]
        linearClient.issueStates = [issue.id: "done"]
        let agentRunner = MockAgentRunner()
        agentRunner.runHandler = { issue, _, _ in
            AsyncThrowingStream { continuation in
                continuation.onTermination = { _ in
                    agentRunner.canceledIssueIDs.append(issue.id)
                }
            }
        }
        let orchestrator = Orchestrator(
            config: makeConfig([:]),
            linearClient: linearClient,
            workspaceManager: MockWorkspaceManager(),
            agentRunner: agentRunner
        )

        // Act
        await orchestrator.pollOnce()
        linearClient.activeIssues = []
        await orchestrator.pollOnce()
        let snapshot = await orchestrator.snapshot()
        await orchestrator.stop()

        // Assert
        XCTAssertTrue(snapshot.running.isEmpty)
        XCTAssertTrue(snapshot.claimed.isEmpty)
        XCTAssertEqual(agentRunner.canceledIssueIDs, [issue.id])
    }

    func test_pollOnce_whenAgentFails_schedulesExponentialBackoffRetries() async throws {
        // Arrange
        let issue = makeIssue(identifier: "DB-189", state: "todo", blockers: [])
        let linearClient = MockLinearClient()
        linearClient.activeIssues = [issue]
        let workspaceManager = MockWorkspaceManager()
        let agentRunner = MockAgentRunner()
        agentRunner.runHandler = { _, _, _ in
            AsyncThrowingStream { continuation in
                let callIndex = agentRunner.receivedIssues.count
                if callIndex <= 2 {
                    continuation.yield(.failed(MockError.sample))
                } else {
                    continuation.yield(.completed)
                }
                continuation.finish()
            }
        }
        var sleepCalls: [UInt64] = []
        let orchestrator = Orchestrator(
            config: makeConfig([
                "maxRetryBackoffMs": 5_000,
                "hooks": [
                    "before_run": "echo before-run",
                    "after_run": "echo after-run",
                ],
            ]),
            linearClient: linearClient,
            workspaceManager: workspaceManager,
            agentRunner: agentRunner,
            nowMs: {
                1_000
            },
            sleep: { duration in
                sleepCalls.append(duration)
            }
        )

        // Act
        await orchestrator.pollOnce()
        await waitForSleepCalls(count: 2, sleepCalls: { sleepCalls.count })
        await orchestrator.stop()

        // Assert
        XCTAssertEqual(agentRunner.receivedIssues.map(\.identifier), ["DB-189", "DB-189"])
        XCTAssertEqual(sleepCalls, [1_000_000_000, 2_000_000_000])
    }

    private func makeConfig(_ overrides: [String: Any]) -> ConfigLayer {
        ConfigLayer(definition: WorkflowDefinition(
            config: overrides.merging([
                "pollIntervalMs": 50,
                "workspaceRoot": "/tmp/symphony-workspaces",
                "activeStates": ["todo"],
                "terminalStates": ["done", "canceled"],
                "maxConcurrentAgents": 2,
                "agentCommand": "codex app-server",
                "turnTimeoutMs": 1_000,
                "stallTimeoutMs": 1_000,
                "hookTimeoutMs": 500,
            ]) { current, _ in current },
            prompt_template: "Handle {{ issue.identifier }}"
        ))
    }

    private func makeIssue(identifier: String, state: String, blockers: [BlockerRef]) -> Issue {
        Issue(
            id: identifier.lowercased(),
            identifier: identifier,
            title: "Issue \(identifier)",
            description: "Description",
            priority: nil,
            state: state,
            branch_name: nil,
            url: nil,
            labels: [],
            blocked_by: blockers,
            created_at: nil,
            updated_at: nil
        )
    }

    private func waitForSleepCalls(count: Int, sleepCalls: () -> Int) async {
        for _ in 0..<100 where sleepCalls() < count {
            await Task.yield()
        }
    }
}

private enum MockError: Error {
    case sample
}
