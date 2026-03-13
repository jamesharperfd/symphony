import Foundation

public struct AgentSession: Codable, Equatable {
    public let sessionId: String
    public let threadId: String
    public let turnId: String
    public let codexAppServerPid: String?
    public let lastCodexEvent: String?
    public let lastCodexTimestamp: Date?
    public let lastCodexMessage: String?
    public let codexInputTokens: Int
    public let codexOutputTokens: Int
    public let codexTotalTokens: Int
    public let turnCount: Int

    public init(
        sessionId: String,
        threadId: String,
        turnId: String,
        codexAppServerPid: String?,
        lastCodexEvent: String?,
        lastCodexTimestamp: Date?,
        lastCodexMessage: String?,
        codexInputTokens: Int,
        codexOutputTokens: Int,
        codexTotalTokens: Int,
        turnCount: Int
    ) {
        self.sessionId = sessionId
        self.threadId = threadId
        self.turnId = turnId
        self.codexAppServerPid = codexAppServerPid
        self.lastCodexEvent = lastCodexEvent
        self.lastCodexTimestamp = lastCodexTimestamp
        self.lastCodexMessage = lastCodexMessage
        self.codexInputTokens = codexInputTokens
        self.codexOutputTokens = codexOutputTokens
        self.codexTotalTokens = codexTotalTokens
        self.turnCount = turnCount
    }
}
