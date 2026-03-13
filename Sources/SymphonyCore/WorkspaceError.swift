import Foundation

public enum WorkspaceError: Error {
    case hookFailed(script: String, exitCode: Int32?, timedOut: Bool)
}
