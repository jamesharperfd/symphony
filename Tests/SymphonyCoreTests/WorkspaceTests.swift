import XCTest
@testable import SymphonyCore

final class WorkspaceTests: XCTestCase {
    func test_workspace_storesInputs() {
        let workspace = Workspace(
            path: "/tmp/workspace",
            workspaceKey: "DB-187",
            createdNow: true
        )

        XCTAssertEqual(workspace.path, "/tmp/workspace")
        XCTAssertEqual(workspace.workspaceKey, "DB-187")
        XCTAssertTrue(workspace.createdNow)
    }
}
