import Foundation
import XCTest
@testable import SymphonyCore

final class WorkflowLoaderTests: XCTestCase {
    func test_load_whenFileHasNoFrontMatter_returnsTrimmedBody() throws {
        let fileURL = try makeWorkflowFile(named: "NoFrontMatter.md", contents: "\n\nShip it.\n")

        let definition = try WorkflowLoader().load(path: fileURL.path)

        XCTAssertEqual(definition.config.count, 0)
        XCTAssertEqual(definition.prompt_template, "Ship it.")
    }

    func test_load_whenFileHasFrontMatter_returnsParsedConfigAndBody() throws {
        let fileURL = try makeWorkflowFile(
            named: "WithFrontMatter.md",
            contents: """
            ---
            pollIntervalMs: 1500
            activeStates:
              - todo
              - in progress
            ---

            Execute the assigned issue.
            """
        )

        let definition = try WorkflowLoader().load(path: fileURL.path)

        XCTAssertEqual(definition.config["pollIntervalMs"] as? Int, 1500)
        XCTAssertEqual(definition.config["activeStates"] as? [String], ["todo", "in progress"])
        XCTAssertEqual(definition.prompt_template, "Execute the assigned issue.")
    }

    func test_load_whenPathIsMissing_throwsMissingFile() {
        let missingPath = "/tmp/does-not-exist-\(UUID().uuidString).md"

        XCTAssertThrowsError(try WorkflowLoader().load(path: missingPath)) { error in
            XCTAssertEqual(error as? WorkflowLoaderError, .missingFile(missingPath))
        }
    }

    func test_load_whenFrontMatterIsNotAMap_throwsInvalidFrontMatter() throws {
        let fileURL = try makeWorkflowFile(
            named: "InvalidFrontMatter.md",
            contents: """
            ---
            - not
            - a
            - map
            ---

            Body
            """
        )

        XCTAssertThrowsError(try WorkflowLoader().load(path: fileURL.path)) { error in
            XCTAssertEqual(error as? WorkflowLoaderError, .invalidFrontMatter)
        }
    }

    func test_load_whenPathIsNil_usesWorkflowInCurrentDirectory() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        let originalDirectory = FileManager.default.currentDirectoryPath
        let fileURL = temporaryDirectory.appendingPathComponent("WORKFLOW.md")

        try "Default workflow body".write(to: fileURL, atomically: true, encoding: .utf8)
        FileManager.default.changeCurrentDirectoryPath(temporaryDirectory.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDirectory) }

        let definition = try WorkflowLoader().load(path: nil)

        XCTAssertEqual(definition.prompt_template, "Default workflow body")
    }

    private func makeWorkflowFile(named fileName: String, contents: String) throws -> URL {
        let directory = try makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(fileName)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
