import Foundation
import XCTest
@testable import SymphonyCore

final class AgentRunnerTests: XCTestCase {
    func test_run_rendersPromptStreamsEventsAndCompletes() async throws {
        // Arrange
        let workspaceRoot = try makeTemporaryDirectory()
        let workspace = Workspace(
            path: workspaceRoot.path,
            workspaceKey: "DB-189",
            createdNow: true
        )
        let promptPath = workspaceRoot.appendingPathComponent("prompt.txt").path
        let runner = AgentRunner(config: makeConfig(
            agentCommand: #"printf '%s' "$SYMPHONY_PROMPT" > "\#(promptPath)"; printf '%s\n' '{"type":"message","text":"hello"}' '{"type":"token_usage","input":3,"output":5}'"#,
            turnTimeoutMs: 1_000,
            stallTimeoutMs: 1_000
        ))
        let issue = makeIssue(
            identifier: "DB-189",
            title: "Build runtime",
            description: "Write tests first"
        )

        // Act
        let events = try await collectEvents(
            from: runner.run(issue: issue, workspace: workspace, promptTemplate: """
            You are working on {{ issue.identifier }}: {{ issue.title }}

            {{ issue.description ?? "" }}
            """)
        )

        // Assert
        let renderedPrompt = try String(contentsOfFile: promptPath, encoding: .utf8)
        XCTAssertEqual(renderedPrompt, """
        You are working on DB-189: Build runtime

        Write tests first
        """)
        XCTAssertEqual(events.map(eventDescription), [
            "message:hello",
            "token:3:5",
            "completed",
        ])
    }

    func test_run_whenNoEventsArriveBeforeStallTimeout_emitsStalled() async throws {
        // Arrange
        let workspace = Workspace(path: try makeTemporaryDirectory().path, workspaceKey: "DB-189", createdNow: true)
        let runner = AgentRunner(config: makeConfig(
            agentCommand: #"printf '%s\n' '{"type":"message","text":"hello"}'; sleep 1"#,
            turnTimeoutMs: 2_000,
            stallTimeoutMs: 100
        ))

        // Act
        let events = try await collectEvents(
            from: runner.run(issue: makeIssue(), workspace: workspace, promptTemplate: "{{ issue.identifier }}")
        )

        // Assert
        XCTAssertEqual(events.map(eventDescription), [
            "message:hello",
            "stalled",
        ])
    }

    func test_run_whenTurnTimeoutExpires_emitsTimedOut() async throws {
        // Arrange
        let workspace = Workspace(path: try makeTemporaryDirectory().path, workspaceKey: "DB-189", createdNow: true)
        let runner = AgentRunner(config: makeConfig(
            agentCommand: "sleep 1",
            turnTimeoutMs: 100,
            stallTimeoutMs: 2_000
        ))

        // Act
        let events = try await collectEvents(
            from: runner.run(issue: makeIssue(), workspace: workspace, promptTemplate: "{{ issue.identifier }}")
        )

        // Assert
        XCTAssertEqual(events.map(eventDescription), ["timedOut"])
    }

    func test_run_whenProcessExitsNonZero_emitsFailed() async throws {
        // Arrange
        let workspace = Workspace(path: try makeTemporaryDirectory().path, workspaceKey: "DB-189", createdNow: true)
        let runner = AgentRunner(config: makeConfig(
            agentCommand: "echo '{\"type\":\"message\",\"text\":\"hello\"}'; exit 7",
            turnTimeoutMs: 1_000,
            stallTimeoutMs: 1_000
        ))

        // Act
        let events = try await collectEvents(
            from: runner.run(issue: makeIssue(), workspace: workspace, promptTemplate: "{{ issue.identifier }}")
        )

        // Assert
        XCTAssertEqual(events.map(eventDescription), [
            "message:hello",
            "failed",
        ])
    }

    private func makeConfig(agentCommand: String, turnTimeoutMs: Int, stallTimeoutMs: Int) -> ConfigLayer {
        ConfigLayer(definition: WorkflowDefinition(
            config: [
                "agentCommand": agentCommand,
                "turnTimeoutMs": turnTimeoutMs,
                "stallTimeoutMs": stallTimeoutMs,
            ],
            prompt_template: "Prompt"
        ))
    }

    private func makeIssue(
        identifier: String = "DB-189",
        title: String = "Build runtime",
        description: String? = nil
    ) -> Issue {
        Issue(
            id: "issue-1",
            identifier: identifier,
            title: title,
            description: description,
            priority: nil,
            state: "todo",
            branch_name: nil,
            url: nil,
            labels: [],
            blocked_by: [],
            created_at: nil,
            updated_at: nil
        )
    }

    private func collectEvents(
        from stream: AsyncThrowingStream<AgentEvent, Error>
    ) async throws -> [AgentEvent] {
        var events: [AgentEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    private func eventDescription(_ event: AgentEvent) -> String {
        switch event {
        case let .message(text):
            return "message:\(text)"
        case let .tokenUpdate(input, output):
            return "token:\(input):\(output)"
        case .completed:
            return "completed"
        case .failed:
            return "failed"
        case .timedOut:
            return "timedOut"
        case .stalled:
            return "stalled"
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
