import Foundation

public final class AgentRunner: AgentRunning {
    private let config: ConfigLayer

    public init(config: ConfigLayer) {
        self.config = config
    }

    public func run(
        issue: Issue,
        workspace: Workspace,
        promptTemplate: String
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        let prompt = renderPrompt(template: promptTemplate, issue: issue)

        return AsyncThrowingStream { continuation in
            let process = Process()
            let stdout = Pipe()
            let state = AgentRunnerState()
            let box = ProcessBox(process: process)

            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-lc", config.agentCommand]
            process.currentDirectoryURL = URL(fileURLWithPath: workspace.path)
            process.standardOutput = stdout
            process.standardError = stdout
            process.environment = ProcessInfo.processInfo.environment.merging([
                "SYMPHONY_PROMPT": prompt,
                "ISSUE_IDENTIFIER": issue.identifier,
                "ISSUE_TITLE": issue.title,
                "ISSUE_DESCRIPTION": issue.description ?? "",
            ]) { _, newValue in
                newValue
            }

            continuation.onTermination = { _ in
                box.stop()
            }

            do {
                try process.run()
            } catch {
                continuation.yield(.failed(error))
                continuation.finish()
                return
            }

            let readerTask = Task {
                do {
                    for try await line in stdout.fileHandleForReading.bytes.lines {
                        await state.markEvent()
                        if let event = AgentRunner.parseEvent(from: line) {
                            continuation.yield(event)
                        }
                    }
                } catch {
                    if await state.finishIfNeeded() {
                        continuation.yield(.failed(error))
                        continuation.finish()
                    }
                }
            }

            let processTask = Task {
                process.waitUntilExit()
                _ = await readerTask.result

                guard await state.finishIfNeeded() else {
                    return
                }

                if process.terminationStatus == 0 {
                    continuation.yield(.completed)
                } else {
                    continuation.yield(.failed(AgentRunnerError.exitCode(process.terminationStatus)))
                }
                continuation.finish()
            }

            let watchdogTask = Task {
                while !(await state.isFinished) {
                    try? await Task.sleep(nanoseconds: 50_000_000)

                    let elapsedSinceEventMs = await state.elapsedSinceLastEventMs()
                    let elapsedSinceStartMs = await state.elapsedSinceStartMs()

                    if elapsedSinceStartMs >= config.turnTimeoutMs {
                        guard await state.finishIfNeeded() else {
                            return
                        }

                        box.stop()
                        continuation.yield(.timedOut)
                        continuation.finish()
                        return
                    }

                    if elapsedSinceEventMs >= config.stallTimeoutMs {
                        guard await state.finishIfNeeded() else {
                            return
                        }

                        box.stop()
                        continuation.yield(.stalled)
                        continuation.finish()
                        return
                    }
                }
            }

            Task {
                _ = await processTask.result
                watchdogTask.cancel()
            }
        }
    }

    private func renderPrompt(template: String, issue: Issue) -> String {
        template
            .replacingOccurrences(of: "{{ issue.identifier }}", with: issue.identifier)
            .replacingOccurrences(of: "{{ issue.title }}", with: issue.title)
            .replacingOccurrences(of: "{{ issue.description ?? \"\" }}", with: issue.description ?? "")
    }

    private static func parseEvent(from line: String) -> AgentEvent? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let type = json["type"] as? String, type == "token_usage" {
            let input = json["input"] as? Int ?? 0
            let output = json["output"] as? Int ?? 0
            return .tokenUpdate(input: input, output: output)
        }

        if let type = json["type"] as? String, type == "message" {
            let text = json["text"] as? String ?? json["message"] as? String ?? json["content"] as? String
            return text.map(AgentEvent.message)
        }

        if let type = json["type"] as? String, type == "content", let content = json["content"] as? String {
            return .message(content)
        }

        if let content = json["content"] as? String {
            return .message(content)
        }

        return nil
    }
}
