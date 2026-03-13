import Foundation

enum SymphonyCommandError: LocalizedError {
    case invalidArguments
    case invalidTrackerKind
    case missingProjectSlug
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Usage: symphony [--workflow <path>]"
        case .invalidTrackerKind:
            return "Workflow tracker.kind must be 'linear'"
        case .missingProjectSlug:
            return "Workflow tracker.project_slug is required"
        case .missingAPIKey:
            return "Workflow tracker.api_key is required"
        }
    }
}
