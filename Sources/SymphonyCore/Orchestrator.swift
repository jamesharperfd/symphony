import Foundation

public actor Orchestrator {
    private let config: ConfigLayer
    private let linearClient: any LinearClienting
    private let workspaceManager: any WorkspaceManaging
    private let agentRunner: any AgentRunning
    private let nowMs: () -> Int
    private let sleep: (UInt64) async -> Void

    private var state: OrchestratorState
    private var pollTask: Task<Void, Never>?
    private var runningTasks: [String: Task<Void, Never>] = [:]
    private var retryTasks: [String: Task<Void, Never>] = [:]

    public init(
        config: ConfigLayer,
        linearClient: any LinearClienting,
        workspaceManager: any WorkspaceManaging,
        agentRunner: any AgentRunning,
        nowMs: @escaping () -> Int = {
            Int(Date().timeIntervalSince1970 * 1_000)
        },
        sleep: @escaping (UInt64) async -> Void = { duration in
            try? await Task.sleep(nanoseconds: duration)
        }
    ) {
        self.config = config
        self.linearClient = linearClient
        self.workspaceManager = workspaceManager
        self.agentRunner = agentRunner
        self.nowMs = nowMs
        self.sleep = sleep
        self.state = OrchestratorState(
            pollIntervalMs: config.pollIntervalMs,
            maxConcurrentAgents: config.maxConcurrentAgents,
            running: [:],
            claimed: [],
            retryAttempts: [:],
            completed: []
        )
    }

    public func start() async {
        guard pollTask == nil else {
            return
        }

        pollTask = Task {
            await self.pollOnce()

            while !Task.isCancelled {
                await self.sleep(UInt64(self.config.pollIntervalMs) * 1_000_000)
                if Task.isCancelled {
                    return
                }
                await self.pollOnce()
            }
        }
    }

    public func stop() async {
        pollTask?.cancel()
        pollTask = nil

        for task in runningTasks.values {
            task.cancel()
        }

        for task in retryTasks.values {
            task.cancel()
        }

        let running = Array(runningTasks.values)
        let retries = Array(retryTasks.values)
        runningTasks.removeAll()
        retryTasks.removeAll()

        for task in running {
            await task.value
        }

        for task in retries {
            await task.value
        }
    }

    public func pollOnce() async {
        let activeIssues: [Issue]

        do {
            activeIssues = try await linearClient.fetchActiveIssues(
                teamSlug: config.projectSlug ?? "",
                states: config.activeStates
            )
        } catch {
            return
        }

        await reconcileRunningIssues(activeIssues: activeIssues)

        let runningCount = state.running.count
        if runningCount >= config.maxConcurrentAgents {
            return
        }

        var availableSlots = config.maxConcurrentAgents - runningCount
        for issue in activeIssues where availableSlots > 0 {
            guard canDispatch(issue: issue) else {
                continue
            }

            availableSlots -= 1
            dispatch(issue: issue, attempt: state.retryAttempts[issue.id]?.attempt ?? 0)
        }
    }

    public func snapshot() -> OrchestratorState {
        state
    }

    private func reconcileRunningIssues(activeIssues: [Issue]) async {
        let activeIssueIDs = Set(activeIssues.map(\.id))
        let runningIssueIDs = Array(state.running.keys)
        let candidateIDs = runningIssueIDs.filter { !activeIssueIDs.contains($0) }

        guard !candidateIDs.isEmpty else {
            return
        }

        guard let fetchedStates = try? await linearClient.fetchIssueStates(ids: candidateIDs) else {
            return
        }

        for issueID in candidateIDs {
            guard let issueState = fetchedStates[issueID]?.lowercased(),
                  normalizedTerminalStates.contains(issueState) else {
                continue
            }

            runningTasks[issueID]?.cancel()
            retryTasks[issueID]?.cancel()
            runningTasks[issueID] = nil
            retryTasks[issueID] = nil
            state = OrchestratorState(
                pollIntervalMs: state.pollIntervalMs,
                maxConcurrentAgents: state.maxConcurrentAgents,
                running: state.running.filter { $0.key != issueID },
                claimed: state.claimed.subtracting([issueID]),
                retryAttempts: state.retryAttempts.filter { $0.key != issueID },
                completed: state.completed
            )
        }
    }

    private func canDispatch(issue: Issue) -> Bool {
        guard !state.claimed.contains(issue.id) else {
            return false
        }

        let normalizedState = issue.state.lowercased()
        guard normalizedActiveStates.contains(normalizedState) else {
            return false
        }

        return issue.blocked_by.allSatisfy { blocker in
            guard let blockerState = blocker.state?.lowercased() else {
                return false
            }

            return normalizedTerminalStates.contains(blockerState)
        }
    }

    private func dispatch(issue: Issue, attempt: Int) {
        var claimed = state.claimed
        claimed.insert(issue.id)

        let runAttempt = RunAttempt(
            issueId: issue.id,
            issueIdentifier: issue.identifier,
            attempt: attempt == 0 ? nil : attempt,
            workspacePath: "",
            startedAt: Date(),
            status: .running,
            error: nil
        )

        var running = state.running
        running[issue.id] = runAttempt
        state = OrchestratorState(
            pollIntervalMs: state.pollIntervalMs,
            maxConcurrentAgents: state.maxConcurrentAgents,
            running: running,
            claimed: claimed,
            retryAttempts: state.retryAttempts,
            completed: state.completed
        )

        let task = Task {
            await self.runIssue(issue: issue, attempt: attempt)
        }
        runningTasks[issue.id] = task
    }

    private func runIssue(issue: Issue, attempt: Int) async {
        do {
            let workspace = try workspaceManager.workspace(for: issue)

            if workspace.createdNow, let afterCreateHook = config.afterCreateHook {
                try workspaceManager.runHook(afterCreateHook, in: workspace, timeoutMs: config.hookTimeoutMs)
            }

            if let beforeRunHook = config.beforeRunHook {
                try workspaceManager.runHook(beforeRunHook, in: workspace, timeoutMs: config.hookTimeoutMs)
            }

            updateWorkspacePath(workspace.path, for: issue.id)

            let stream = agentRunner.run(
                issue: issue,
                workspace: workspace,
                promptTemplate: config.promptTemplate
            )

            var terminalFailure: Error?
            for try await event in stream {
                switch event {
                case .completed:
                    break
                case let .failed(error):
                    terminalFailure = error
                case .timedOut:
                    terminalFailure = OrchestratorError.agentTimedOut(issue.identifier)
                case .stalled:
                    terminalFailure = OrchestratorError.agentStalled(issue.identifier)
                case .message, .tokenUpdate:
                    continue
                }
            }

            if let afterRunHook = config.afterRunHook {
                try? workspaceManager.runHook(afterRunHook, in: workspace, timeoutMs: config.hookTimeoutMs)
            }

            if let terminalFailure {
                await scheduleRetry(for: issue, attempt: attempt + 1, error: terminalFailure)
            } else {
                markCompleted(issueID: issue.id)
            }
        } catch {
            await scheduleRetry(for: issue, attempt: attempt + 1, error: error)
        }
    }

    private func updateWorkspacePath(_ path: String, for issueID: String) {
        guard let existing = state.running[issueID] else {
            return
        }

        var running = state.running
        running[issueID] = RunAttempt(
            issueId: existing.issueId,
            issueIdentifier: existing.issueIdentifier,
            attempt: existing.attempt,
            workspacePath: path,
            startedAt: existing.startedAt,
            status: existing.status,
            error: existing.error
        )
        state = OrchestratorState(
            pollIntervalMs: state.pollIntervalMs,
            maxConcurrentAgents: state.maxConcurrentAgents,
            running: running,
            claimed: state.claimed,
            retryAttempts: state.retryAttempts,
            completed: state.completed
        )
    }

    private func scheduleRetry(for issue: Issue, attempt: Int, error: Error) async {
        let delayMs = retryDelayMs(for: attempt)
        let dueAtMs = nowMs() + delayMs

        var running = state.running
        running.removeValue(forKey: issue.id)

        var retryAttempts = state.retryAttempts
        retryAttempts[issue.id] = RetryEntry(
            issueId: issue.id,
            identifier: issue.identifier,
            attempt: attempt,
            dueAtMs: dueAtMs,
            error: String(describing: error)
        )

        state = OrchestratorState(
            pollIntervalMs: state.pollIntervalMs,
            maxConcurrentAgents: state.maxConcurrentAgents,
            running: running,
            claimed: state.claimed,
            retryAttempts: retryAttempts,
            completed: state.completed
        )

        runningTasks[issue.id] = nil

        let retryTask = Task.detached {
            await self.sleep(UInt64(delayMs) * 1_000_000)
            await self.retry(issue: issue, attempt: attempt)
        }
        retryTasks[issue.id] = retryTask
    }

    private func retry(issue: Issue, attempt: Int) async {
        retryTasks[issue.id] = nil
        dispatch(issue: issue, attempt: attempt)
    }

    private func markCompleted(issueID: String) {
        var running = state.running
        running.removeValue(forKey: issueID)

        var claimed = state.claimed
        claimed.remove(issueID)

        var completed = state.completed
        completed.insert(issueID)

        var retryAttempts = state.retryAttempts
        retryAttempts.removeValue(forKey: issueID)

        state = OrchestratorState(
            pollIntervalMs: state.pollIntervalMs,
            maxConcurrentAgents: state.maxConcurrentAgents,
            running: running,
            claimed: claimed,
            retryAttempts: retryAttempts,
            completed: completed
        )

        runningTasks[issueID] = nil
    }

    private func retryDelayMs(for attempt: Int) -> Int {
        let exponent = max(0, attempt - 1)
        let delay = 1_000 * Int(pow(2.0, Double(exponent)))
        return min(config.maxRetryBackoffMs, max(1_000, delay))
    }

    private var normalizedActiveStates: Set<String> {
        Set(config.activeStates.map { $0.lowercased() })
    }

    private var normalizedTerminalStates: Set<String> {
        Set(config.terminalStates.map { $0.lowercased() })
    }
}
