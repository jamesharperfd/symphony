import Foundation

public struct WorkflowConfig {
    private let config: [String: Any]

    public init(config: [String: Any]) {
        self.config = config
    }

    public var trackerKind: String? {
        optionalStringValue(section: "tracker", key: "kind", legacyKeys: ["trackerKind"])
    }
    public var projectSlug: String? {
        optionalStringValue(section: "tracker", key: "project_slug", legacyKeys: ["projectSlug"])
    }
    public var apiKey: String? {
        optionalStringValue(section: "tracker", key: "api_key", legacyKeys: ["apiKey"])
    }
    public var pollIntervalMs: Int {
        intValue(
            section: "polling",
            key: "interval_ms",
            legacyKeys: ["pollIntervalMs"],
            default: 30_000
        )
    }
    public var workspaceRoot: String {
        expandPath(
            stringValue(
                section: "workspace",
                key: "root",
                legacyKeys: ["workspaceRoot"],
                default: "/symphony_workspaces"
            )
        )
    }
    public var afterCreateHook: String? {
        optionalStringValue(section: "hooks", key: "after_create", legacyKeys: ["afterCreateHook"])
    }
    public var beforeRunHook: String? {
        optionalStringValue(section: "hooks", key: "before_run", legacyKeys: ["beforeRunHook"])
    }
    public var afterRunHook: String? {
        optionalStringValue(section: "hooks", key: "after_run", legacyKeys: ["afterRunHook"])
    }
    public var beforeRemoveHook: String? {
        optionalStringValue(section: "hooks", key: "before_remove", legacyKeys: ["beforeRemoveHook"])
    }
    public var activeStates: [String] {
        stringArrayValue(
            section: nil,
            key: nil,
            legacyKeys: ["activeStates"],
            default: ["todo", "in progress"]
        )
    }
    public var terminalStates: [String] {
        stringArrayValue(
            section: nil,
            key: nil,
            legacyKeys: ["terminalStates"],
            default: ["closed", "cancelled", "canceled", "duplicate", "done"]
        )
    }
    public var maxConcurrentAgents: Int {
        intValue(
            section: "agent",
            key: "max_concurrent_agents",
            legacyKeys: ["maxConcurrentAgents"],
            default: 10
        )
    }
    public var maxConcurrentAgentsByState: [String: Int] {
        dictionaryOfIntsValue(
            section: "agent",
            key: "max_concurrent_agents_by_state",
            legacyKeys: ["maxConcurrentAgentsByState"]
        )
    }
    public var maxRetryBackoffMs: Int {
        intValue(
            section: "agent",
            key: "max_retry_backoff_ms",
            legacyKeys: ["maxRetryBackoffMs"],
            default: 300_000
        )
    }
    public var agentCommand: String {
        stringValue(
            section: "codex",
            key: "command",
            legacyKeys: ["agentCommand"],
            default: "codex app-server"
        )
    }
    public var turnTimeoutMs: Int {
        intValue(
            section: "codex",
            key: "turn_timeout_ms",
            legacyKeys: ["turnTimeoutMs"],
            default: 3_600_000
        )
    }
    public var stallTimeoutMs: Int {
        intValue(
            section: "codex",
            key: "stall_timeout_ms",
            legacyKeys: ["stallTimeoutMs"],
            default: 300_000
        )
    }
    public var readTimeoutMs: Int {
        intValue(
            section: "codex",
            key: "read_timeout_ms",
            legacyKeys: ["readTimeoutMs"],
            default: 5_000
        )
    }
    public var hookTimeoutMs: Int {
        intValue(
            section: "hooks",
            key: "timeout_ms",
            legacyKeys: ["hookTimeoutMs"],
            default: 60_000
        )
    }

    private func intValue(
        section: String?,
        key: String?,
        legacyKeys: [String],
        default defaultValue: Int
    ) -> Int {
        guard let resolvedValue = resolveValue(section: section, key: key, legacyKeys: legacyKeys) else {
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

    private func stringValue(
        section: String?,
        key: String?,
        legacyKeys: [String],
        default defaultValue: String
    ) -> String {
        guard let resolvedValue = resolveValue(section: section, key: key, legacyKeys: legacyKeys) else {
            return defaultValue
        }

        return resolvedValue as? String ?? defaultValue
    }

    private func optionalStringValue(section: String, key: String, legacyKeys: [String]) -> String? {
        resolveValue(section: section, key: key, legacyKeys: legacyKeys) as? String
    }

    private func stringArrayValue(
        section: String?,
        key: String?,
        legacyKeys: [String],
        default defaultValue: [String]
    ) -> [String] {
        guard let resolvedValue = resolveValue(section: section, key: key, legacyKeys: legacyKeys) else {
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

    private func resolveValue(section: String?, key: String?, legacyKeys: [String]) -> Any? {
        if let section, let key, let nestedValue = dictionaryValue(for: section)?[key] {
            return resolveEnvironmentValue(nestedValue)
        }

        for legacyKey in legacyKeys {
            if let value = config[legacyKey] {
                return resolveEnvironmentValue(value)
            }
        }

        return nil
    }

    private func dictionaryOfIntsValue(section: String, key: String, legacyKeys: [String]) -> [String: Int] {
        guard let resolvedValue = resolveValue(section: section, key: key, legacyKeys: legacyKeys) else {
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

    private func dictionaryValue(for key: String) -> [String: Any]? {
        if let values = config[key] as? [String: Any] {
            return values
        }

        if let values = config[key] as? [AnyHashable: Any] {
            var normalizedValues: [String: Any] = [:]
            for (rawKey, value) in values {
                guard let stringKey = rawKey as? String else {
                    continue
                }
                normalizedValues[stringKey] = value
            }
            return normalizedValues
        }

        return nil
    }

    private func resolveEnvironmentValue(_ value: Any) -> Any? {
        if let stringValue = value as? String, stringValue.hasPrefix("$") {
            let environmentKey = String(stringValue.dropFirst())
            return ProcessInfo.processInfo.environment[environmentKey]
        }

        return value
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
