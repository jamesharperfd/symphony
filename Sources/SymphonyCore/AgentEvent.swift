import Foundation

public enum AgentEvent {
    case message(String)
    case tokenUpdate(input: Int, output: Int)
    case completed
    case failed(Error)
    case timedOut
    case stalled
}
