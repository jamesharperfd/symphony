import Foundation

struct StructuredLogger {
    private let dateFormatter: ISO8601DateFormatter

    init() {
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func log(level: String, component: String, message: String) {
        let payload: [String: String] = [
            "timestamp": dateFormatter.string(from: Date()),
            "level": level,
            "component": component,
            "message": message,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: data, encoding: .utf8) else {
            print("{\"level\":\"error\",\"component\":\"logger\",\"message\":\"Failed to encode log line\"}")
            fflush(stdout)
            return
        }

        print(line)
        fflush(stdout)
    }
}
