import Foundation

public final class WorkspaceManager: WorkspaceManaging {
    private let root: String
    private let beforeRemoveHook: String?
    private let logger: (String) -> Void
    private let fileManager: FileManager

    public init(
        root: String,
        beforeRemoveHook: String? = nil,
        logger: @escaping (String) -> Void = { _ in },
        fileManager: FileManager = .default
    ) {
        self.root = URL(fileURLWithPath: NSString(string: root).expandingTildeInPath)
            .resolvingSymlinksInPath()
            .path
        self.beforeRemoveHook = beforeRemoveHook
        self.logger = logger
        self.fileManager = fileManager
    }

    public func workspace(for issue: Issue) throws -> Workspace {
        let workspaceKey = Self.sanitize(identifier: issue.identifier)
        let path = URL(fileURLWithPath: root).appendingPathComponent(workspaceKey).path
        let createdNow = !fileManager.fileExists(atPath: path)

        if createdNow {
            try fileManager.createDirectory(
                at: URL(fileURLWithPath: path),
                withIntermediateDirectories: true
            )
        }

        return Workspace(path: path, workspaceKey: workspaceKey, createdNow: createdNow)
    }

    public func runHook(_ script: String, in workspace: Workspace, timeoutMs: Int) throws {
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        try Self.runProcess(
            script: script,
            in: workspace.path,
            timeoutMs: timeoutMs
        )
    }

    public func removeWorkspace(for identifier: String) throws {
        let workspaceKey = Self.sanitize(identifier: identifier)
        let path = URL(fileURLWithPath: root).appendingPathComponent(workspaceKey).path

        guard fileManager.fileExists(atPath: path) else {
            return
        }

        if let beforeRemoveHook {
            do {
                try runHook(
                    beforeRemoveHook,
                    in: Workspace(path: path, workspaceKey: workspaceKey, createdNow: false),
                    timeoutMs: 60_000
                )
            } catch {
                logger("before_remove hook failed for \(identifier): \(error)")
            }
        }

        try fileManager.removeItem(at: URL(fileURLWithPath: path))
    }

    private static func sanitize(identifier: String) -> String {
        identifier.replacingOccurrences(
            of: #"[^A-Za-z0-9._-]"#,
            with: "_",
            options: .regularExpression
        )
    }

    private static func runProcess(script: String, in path: String, timeoutMs: Int) throws {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let completion = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-lc", script]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { _ in
            completion.signal()
        }

        try process.run()

        let timeout = DispatchTime.now() + .milliseconds(timeoutMs)
        if completion.wait(timeout: timeout) == .timedOut {
            process.terminate()
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            _ = completion.wait(timeout: .now() + .milliseconds(500))
            throw WorkspaceError.hookFailed(script: script, exitCode: nil, timedOut: true)
        }

        guard process.terminationStatus == 0 else {
            throw WorkspaceError.hookFailed(
                script: script,
                exitCode: process.terminationStatus,
                timedOut: false
            )
        }
    }
}
