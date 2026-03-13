import Foundation

public struct WorkflowDefinition {
    public let config: [String: Any]
    public let prompt_template: String

    public init(config: [String: Any], prompt_template: String) {
        self.config = config
        self.prompt_template = prompt_template
    }
}
