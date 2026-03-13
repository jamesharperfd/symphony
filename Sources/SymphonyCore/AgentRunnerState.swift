import Foundation

actor AgentRunnerState {
    private let startedAt = Date()
    private var lastEventAt = Date()
    private var finished = false

    var isFinished: Bool {
        finished
    }

    func markEvent() {
        lastEventAt = Date()
    }

    func finishIfNeeded() -> Bool {
        if finished {
            return false
        }

        finished = true
        return true
    }

    func elapsedSinceStartMs() -> Int {
        Int(Date().timeIntervalSince(startedAt) * 1_000)
    }

    func elapsedSinceLastEventMs() -> Int {
        Int(Date().timeIntervalSince(lastEventAt) * 1_000)
    }
}
