import XCTest
@testable import SymphonyCore

final class RetryEntryTests: XCTestCase {
    func test_retryEntry_whenCodable_roundTripsFields() throws {
        let entry = RetryEntry(
            issueId: "123",
            identifier: "DB-187",
            attempt: 1,
            dueAtMs: 123_456,
            error: "transient failure"
        )

        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(RetryEntry.self, from: encoded)

        XCTAssertEqual(decoded, entry)
    }
}
