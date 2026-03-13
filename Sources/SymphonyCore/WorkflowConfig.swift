import Foundation

public struct WorkflowConfig {
    private let config: [String: Any]

    public init(config: [String: Any]) {
        self.config = config
    }

    public var pollIntervalMs: Int { intValue(for: "pollIntervalMs", default: 30_000) }
    public var workspaceRoot: String {
        expandPath(stringValue(for: "workspaceRoot", default: "/symphony_workspaces"))
    }
    public var activeStates: [String] {
        stringArrayValue(for: "activeStates", default: ["todo", "in progress"])
    }
    public var terminalStates: [String] {
        stringArrayValue(for: "terminalStates", default: ["closed", "cancelled", "canceled", "duplicate", "done"])
    }
    public var maxConcurrentAgents: Int { intValue(for: "maxConcurrentAgents", default: 10) }
    public var maxConcurrentAgentsByState: [String: Int] {
        dictionaryOfIntsValue(for: "maxConcurrentAgentsByState")
    }
    public var maxRetryBackoffMs: Int { intValue(for: "maxRetryBackoffMs", default: 300_000) }
    public var agentCommand: String { stringValue(for: "agentCommand", default: "codex app-server") }
    public var turnTimeoutMs: Int { intValue(for: "turnTimeoutMs", default: 3_600_000) }
    public var stallTimeoutMs: Int { intValue(for: "stallTimeoutMs", default: 300_000) }
    public var readTimeoutMs: Int { intValue(for: "readTimeoutMs", default: 5_000) }
    public var hookTimeoutMs: Int { intValue(for: "hookTimeoutMs", default: 60_000) }

    private func intValue(for key: String, default defaultValue: Int) -> Int {
        guard let resolvedValue = resolveValue(for: key) else {
            return defaultValue
        }

        if let value = resolvedValue as? Int {
            return value
        }

        if let value = resolvedValue as? String, let intValue = Int(value) {
            return intValue
        }

        return defaultValue
    }

    private func stringValue(for key: String, default defaultValue: String) -> String {
        guard let resolvedValue = resolveValue(for: key) else {
            return defaultValue
        }

        return resolvedValue as? String ?? defaultValue
    }

    private func stringArrayValue(for key: String, default defaultValue: [String]) -> [String] {
        guard let resolvedValue = resolveValue(for: key) else {
            return defaultValue
        }

        if let values = resolvedValue as? [String] {
            return values
        }

        if let values = resolvedValue as? [Any] {
            let strings = values.compactMap { $0 as? String }
            return strings.isEmpty ? defaultValue : strings
        }

        if let value = resolvedValue as? String {
            let values = value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return values.isEmpty ? defaultValue : values
        }

        return defaultValue
    }

    private func resolveValue(for key: String) -> Any? {
        guard let value = config[key] else {
            return nil
        }

        if let stringValue = value as? String, stringValue.hasPrefix("$") {
            let environmentKey = String(stringValue.dropFirst())
            return ProcessInfo.processInfo.environment[environmentKey]
        }

        return value
    }

    private func dictionaryOfIntsValue(for key: String) -> [String: Int] {
        guard let resolvedValue = resolveValue(for: key) else {
            return [:]
        }

        guard let values = resolvedValue as? [String: Any] else {
            return [:]
        }

        var normalizedValues: [String: Int] = [:]
        for (state, rawValue) in values {
            guard let parsedValue = int(from: rawValue) else {
                continue
            }

            normalizedValues[state.lowercased()] = parsedValue
        }

        return normalizedValues
    }

    private func int(from value: Any) -> Int? {
        if let value = value as? Int {
            return value
        }

        if let value = value as? String {
            return Int(value)
        }

        return nil
    }

    private func expandPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}
