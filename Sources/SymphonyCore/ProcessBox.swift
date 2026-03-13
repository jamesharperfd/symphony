import Foundation

final class ProcessBox: @unchecked Sendable {
    let process: Process

    init(process: Process) {
        self.process = process
    }

    func stop() {
        guard process.isRunning else {
            return
        }

        process.terminate()
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
    }
}
