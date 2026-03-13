import Foundation
import XCTest
@testable import SymphonyCore

final class OrchestratorStateTests: XCTestCase {
    func test_orchestratorState_whenCodable_roundTripsNestedModels() throws {
        let runAttempt = RunAttempt(
            issueId: "123",
            issueIdentifier: "DB-187",
            attempt: 1,
            workspacePath: "/tmp/workspace",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            status: .pending,
            error: nil
        )
        let retryEntry = RetryEntry(
            issueId: "123",
            identifier: "DB-187",
            attempt: 1,
            dueAtMs: 123_456,
            error: nil
        )
        let state = OrchestratorState(
            pollIntervalMs: 30_000,
            maxConcurrentAgents: 10,
            running: ["DB-187": runAttempt],
            claimed: ["DB-187"],
            retryAttempts: ["DB-187": retryEntry],
            completed: ["DB-100"]
        )

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(OrchestratorState.self, from: encoded)

        XCTAssertEqual(decoded, state)
    }
}
