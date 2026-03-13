import Foundation
import XCTest
@testable import SymphonyCore

final class RunAttemptTests: XCTestCase {
    func test_runAttempt_whenCodable_roundTripsStatus() throws {
        let attempt = RunAttempt(
            issueId: "123",
            issueIdentifier: "DB-187",
            attempt: 2,
            workspacePath: "/tmp/workspace",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            status: .running,
            error: "timeout"
        )

        let encoded = try JSONEncoder().encode(attempt)
        let decoded = try JSONDecoder().decode(RunAttempt.self, from: encoded)

        XCTAssertEqual(decoded, attempt)
    }
}
