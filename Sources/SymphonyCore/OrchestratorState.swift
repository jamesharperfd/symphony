import Foundation

public struct OrchestratorState: Codable, Equatable {
    public let pollIntervalMs: Int
    public let maxConcurrentAgents: Int
    public let running: [String: RunAttempt]
    public let claimed: Set<String>
    public let retryAttempts: [String: RetryEntry]
    public let completed: Set<String>

    public init(
        pollIntervalMs: Int,
        maxConcurrentAgents: Int,
        running: [String: RunAttempt],
        claimed: Set<String>,
        retryAttempts: [String: RetryEntry],
        completed: Set<String>
    ) {
        self.pollIntervalMs = pollIntervalMs
        self.maxConcurrentAgents = maxConcurrentAgents
        self.running = running
        self.claimed = claimed
        self.retryAttempts = retryAttempts
        self.completed = completed
    }
}
