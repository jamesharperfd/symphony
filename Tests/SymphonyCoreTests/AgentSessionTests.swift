import Foundation
import XCTest
@testable import SymphonyCore

final class AgentSessionTests: XCTestCase {
    func test_agentSession_whenCodable_roundTripsAllFields() throws {
        let session = AgentSession(
            sessionId: "session-1",
            threadId: "thread-1",
            turnId: "turn-1",
            codexAppServerPid: "999",
            lastCodexEvent: "message",
            lastCodexTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            lastCodexMessage: "working",
            codexInputTokens: 10,
            codexOutputTokens: 20,
            codexTotalTokens: 30,
            turnCount: 2
        )

        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(AgentSession.self, from: encoded)

        XCTAssertEqual(decoded, session)
    }
}
