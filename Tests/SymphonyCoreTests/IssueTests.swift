import Foundation
import XCTest
@testable import SymphonyCore

final class IssueTests: XCTestCase {
    func test_issue_whenDecodedFromJSON_populatesAllFields() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let issue = Issue(
            id: "123",
            identifier: "DB-187",
            title: "Implement workflow loader",
            description: "Load workflow markdown files",
            priority: 1,
            state: "todo",
            branch_name: "kai/db-187-symphony-models",
            url: "https://example.com/issues/123",
            labels: ["backend", "swift"],
            blocked_by: [
                BlockerRef(id: "99", identifier: "DB-99", state: "done")
            ],
            created_at: createdAt,
            updated_at: updatedAt
        )

        let encoded = try JSONEncoder().encode(issue)
        let decoded = try JSONDecoder().decode(Issue.self, from: encoded)

        XCTAssertEqual(decoded, issue)
    }
}
