import Foundation

public enum OrchestratorError: Error {
    case agentTimedOut(String)
    case agentStalled(String)
}
