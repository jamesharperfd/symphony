import Foundation
import XCTest
@testable import SymphonyCore

final class WorkspaceManagerTests: XCTestCase {
    func test_workspace_forIssue_sanitizesIdentifierAndCreatesDirectory() throws {
        // Arrange
        let root = try makeTemporaryDirectory()
        let manager = WorkspaceManager(root: root.path)
        let issue = makeIssue(identifier: "DB 189/alpha?")

        // Act
        let workspace = try manager.workspace(for: issue)

        // Assert
        XCTAssertEqual(workspace.workspaceKey, "DB_189_alpha_")
        XCTAssertEqual(workspace.path, root.appendingPathComponent("DB_189_alpha_").path)
        XCTAssertTrue(workspace.createdNow)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.path))
    }

    func test_workspace_forIssue_whenDirectoryAlreadyExists_returnsCreatedNowFalse() throws {
        // Arrange
        let root = try makeTemporaryDirectory()
        let existingWorkspace = root.appendingPathComponent("DB-189")
        try FileManager.default.createDirectory(at: existingWorkspace, withIntermediateDirectories: true)
        let manager = WorkspaceManager(root: root.path)

        // Act
        let workspace = try manager.workspace(for: makeIssue(identifier: "DB-189"))

        // Assert
        XCTAssertFalse(workspace.createdNow)
        XCTAssertEqual(workspace.path, existingWorkspace.path)
    }

    func test_runHook_executesScriptInsideWorkspaceDirectory() throws {
        // Arrange
        let root = try makeTemporaryDirectory()
        let manager = WorkspaceManager(root: root.path)
        let workspace = try manager.workspace(for: makeIssue(identifier: "DB-189"))
        let outputPath = root.appendingPathComponent("pwd.txt").path
        let script = #"printf '%s' "$PWD" > "\#(outputPath)""#

        // Act
        try manager.runHook(script, in: workspace, timeoutMs: 1_000)

        // Assert
        let capturedPath = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertEqual(normalizePath(capturedPath), normalizePath(workspace.path))
    }

    func test_runHook_whenScriptTimesOut_throwsHookFailed() throws {
        // Arrange
        let root = try makeTemporaryDirectory()
        let manager = WorkspaceManager(root: root.path)
        let workspace = try manager.workspace(for: makeIssue(identifier: "DB-189"))

        // Act
        XCTAssertThrowsError(try manager.runHook("sleep 1", in: workspace, timeoutMs: 50)) { error in
            guard case WorkspaceError.hookFailed = error else {
                return XCTFail("Expected hookFailed, got \(error)")
            }
        }
    }

    func test_removeWorkspace_whenBeforeRemoveHookExists_runsHookAndRemovesDirectory() throws {
        // Arrange
        let root = try makeTemporaryDirectory()
        let hookOutput = root.appendingPathComponent("before-remove.txt")
        let hook = #"printf '%s' "$PWD" > "\#(hookOutput.path)""#
        let manager = WorkspaceManager(root: root.path, beforeRemoveHook: hook)
        let workspace = try manager.workspace(for: makeIssue(identifier: "DB-189"))

        // Act
        try manager.removeWorkspace(for: "DB-189")

        // Assert
        let capturedPath = try String(contentsOf: hookOutput, encoding: .utf8)
        XCTAssertEqual(normalizePath(capturedPath), normalizePath(workspace.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.path))
    }

    func test_removeWorkspace_whenBeforeRemoveHookFails_logsAndStillRemovesDirectory() throws {
        // Arrange
        let root = try makeTemporaryDirectory()
        var logs: [String] = []
        let manager = WorkspaceManager(
            root: root.path,
            beforeRemoveHook: "exit 7",
            logger: { logs.append($0) }
        )
        let workspace = try manager.workspace(for: makeIssue(identifier: "DB-189"))

        // Act
        try manager.removeWorkspace(for: "DB-189")

        // Assert
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.path))
        XCTAssertEqual(logs.count, 1)
        XCTAssertTrue(logs[0].contains("before_remove"))
    }

    private func makeIssue(identifier: String) -> Issue {
        Issue(
            id: identifier.lowercased(),
            identifier: identifier,
            title: "Title",
            description: "Description",
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

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func normalizePath(_ path: String) -> String {
        let resolvedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        if resolvedPath.hasPrefix("/private/") {
            return String(resolvedPath.dropFirst("/private".count))
        }

        return resolvedPath
    }
}
