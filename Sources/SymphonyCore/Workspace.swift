import Foundation

public struct Workspace: Codable, Equatable {
    public let path: String
    public let workspaceKey: String
    public let createdNow: Bool

    public init(path: String, workspaceKey: String, createdNow: Bool) {
        self.path = path
        self.workspaceKey = workspaceKey
        self.createdNow = createdNow
    }
}
