import Foundation
import SymphonyCore

enum SymphonyCommand {
    static func run() async -> Int32 {
        let logger = StructuredLogger()

        do {
            let workflowPath = try parseWorkflowPath(arguments: CommandLine.arguments)
            let definition = try WorkflowLoader().load(path: workflowPath)
            let config = ConfigLayer(definition: definition)

            try validate(config: config)

            let linearClient = LinearClient(apiKey: config.apiKey ?? "")
            let workspaceManager = WorkspaceManager(
                root: config.workspaceRoot,
                beforeRemoveHook: config.beforeRemoveHook,
                logger: { message in
                    logger.log(level: "warn", component: "workspace", message: message)
                }
            )
            let agentRunner = AgentRunner(config: config)
            let orchestrator = Orchestrator(
                config: config,
                linearClient: linearClient,
                workspaceManager: workspaceManager,
                agentRunner: agentRunner
            )

            logger.log(level: "info", component: "symphony", message: "Starting orchestrator")
            await orchestrator.start()

            let signal = await SignalStream(signals: [SIGINT, SIGTERM]).firstSignal()
            logger.log(level: "info", component: "symphony", message: "Received signal \(signal), stopping")
            await orchestrator.stop()
            logger.log(level: "info", component: "symphony", message: "Shutdown complete")
            return 0
        } catch let error as SymphonyCommandError {
            logger.log(level: "error", component: "symphony", message: error.localizedDescription)
            return 1
        } catch {
            logger.log(level: "error", component: "symphony", message: String(describing: error))
            return 1
        }
    }

    private static func parseWorkflowPath(arguments: [String]) throws -> String? {
        guard arguments.count > 1 else {
            return nil
        }

        guard arguments.count == 3, arguments[1] == "--workflow" else {
            throw SymphonyCommandError.invalidArguments
        }

        return arguments[2]
    }

    private static func validate(config: ConfigLayer) throws {
        guard config.trackerKind?.lowercased() == "linear" else {
            throw SymphonyCommandError.invalidTrackerKind
        }

        guard let projectSlug = config.projectSlug, !projectSlug.isEmpty else {
            throw SymphonyCommandError.missingProjectSlug
        }

        guard let apiKey = config.apiKey, !apiKey.isEmpty else {
            throw SymphonyCommandError.missingAPIKey
        }
    }
}

Task {
    Foundation.exit(await SymphonyCommand.run())
}

dispatchMain()
