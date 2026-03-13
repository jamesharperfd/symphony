import Foundation

final class SignalStream {
    private let signals: [Int32]
    private let sourceStore = SignalSourceStore()

    init(signals: [Int32]) {
        self.signals = signals
    }

    func firstSignal() async -> Int32 {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        return await withCheckedContinuation { continuation in
            sourceStore.sources = signals.map { signalValue in
                let source = DispatchSource.makeSignalSource(signal: signalValue, queue: .main)
                source.setEventHandler {
                    continuation.resume(returning: signalValue)
                }
                source.resume()
                return source
            }
        }
    }
}
