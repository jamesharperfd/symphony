import XCTest
@testable import SymphonyCore

final class WorkflowDefinitionTests: XCTestCase {
    func test_workflowDefinition_storesConfigAndPromptTemplate() {
        let definition = WorkflowDefinition(
            config: [
                "pollIntervalMs": 1_000,
                "activeStates": ["todo"]
            ],
            prompt_template: "Execute the issue"
        )

        XCTAssertEqual(definition.prompt_template, "Execute the issue")
        XCTAssertEqual(definition.config["pollIntervalMs"] as? Int, 1_000)
        XCTAssertEqual(definition.config["activeStates"] as? [String], ["todo"])
    }
}
