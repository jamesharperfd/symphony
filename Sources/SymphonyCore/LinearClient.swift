import Foundation

public enum LinearClientError: Error, Equatable {
    case httpError(Int)
    case decodingError(Error)
    case apiError(String)

    public static func == (lhs: LinearClientError, rhs: LinearClientError) -> Bool {
        switch (lhs, rhs) {
        case let (.httpError(leftCode), .httpError(rightCode)):
            return leftCode == rightCode
        case let (.apiError(leftMessage), .apiError(rightMessage)):
            return leftMessage == rightMessage
        case (.decodingError, .decodingError):
            return true
        default:
            return false
        }
    }
}

public struct LinearClient {
    private let apiKey: String
    private let endpoint: URL
    private let session: URLSession

    public init(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.linear.app/graphql")!
    ) {
        self.init(apiKey: apiKey, endpoint: endpoint, session: .shared)
    }

    init(apiKey: String, endpoint: URL, session: URLSession) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.session = session
    }

    public func fetchActiveIssues(teamSlug: String, states: [String]) async throws -> [Issue] {
        let request = GraphQLRequest(
            query: """
            query FetchActiveIssues($teamSlug: String!, $states: [String!]!) {
              issues(filter: { project: { slug: { eq: $teamSlug } }, state: { name: { in: $states } } }) {
                nodes {
                  id
                  identifier
                  title
                  description
                  priority
                  state { name }
                  branchName
                  url
                  labels { nodes { name } }
                  relations { nodes { relatedIssue { id identifier state { name } } } }
                }
              }
            }
            """,
            variables: [
                "teamSlug": teamSlug,
                "states": states,
            ]
        )

        let response: IssuesPayload = try await perform(request, responseType: IssuesPayload.self)
        return response.issues.nodes.map(\.issue)
    }

    public func fetchIssueStates(ids: [String]) async throws -> [String: String] {
        let request = GraphQLRequest(
            query: """
            query FetchIssueStates($ids: [String!]!) {
              issues(filter: { id: { in: $ids } }) {
                nodes {
                  id
                  state { name }
                }
              }
            }
            """,
            variables: ["ids": ids]
        )

        let response: IssueStatesPayload = try await perform(request, responseType: IssueStatesPayload.self)
        return Dictionary(
            uniqueKeysWithValues: response.issues.nodes.map { node in
                (node.id, node.state.name.normalizedLinearValue)
            }
        )
    }

    public func fetchTerminalIssues(teamSlug: String, states: [String]) async throws -> [Issue] {
        try await fetchActiveIssues(teamSlug: teamSlug, states: states)
    }

    private func perform<Response: Decodable>(
        _ graphQLRequest: GraphQLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(graphQLRequest)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinearClientError.httpError(-1)
        }

        guard httpResponse.statusCode == 200 else {
            throw LinearClientError.httpError(httpResponse.statusCode)
        }

        do {
            let apiResponse = try JSONDecoder().decode(GraphQLResponse<Response>.self, from: data)
            if let message = apiResponse.errors?.first?.message {
                throw LinearClientError.apiError(message)
            }
            guard let responseData = apiResponse.data else {
                let context = DecodingError.Context(
                    codingPath: [],
                    debugDescription: "GraphQL response missing data"
                )
                throw LinearClientError.decodingError(
                    DecodingError.valueNotFound(Response.self, context)
                )
            }
            return responseData
        } catch let error as LinearClientError {
            throw error
        } catch {
            throw LinearClientError.decodingError(error)
        }
    }
}

private struct GraphQLRequest: Encodable {
    let query: String
    let variables: [String: EncodableValue]

    init(query: String, variables: [String: Any]) {
        self.query = query
        self.variables = variables.mapValues(EncodableValue.init)
    }
}

private struct GraphQLResponse<Data: Decodable>: Decodable {
    let data: Data?
    let errors: [GraphQLError]?
}

private struct GraphQLError: Decodable {
    let message: String
}

private struct IssuesPayload: Decodable {
    struct IssuesContainer: Decodable {
        let nodes: [LinearIssue]
    }

    let issues: IssuesContainer
}

private struct IssueStatesPayload: Decodable {
    struct IssuesContainer: Decodable {
        let nodes: [IssueStateNode]
    }

    let issues: IssuesContainer
}

private struct IssueStateNode: Decodable {
    let id: String
    let state: LinearState
}

private struct LinearIssue: Decodable {
    let id: String
    let identifier: String
    let title: String
    let description: String?
    let priority: Int?
    let state: LinearState
    let branchName: String?
    let url: String?
    let labels: LinearLabels
    let relations: LinearRelations

    var issue: Issue {
        Issue(
            id: id,
            identifier: identifier,
            title: title,
            description: description,
            priority: priority,
            state: state.name.normalizedLinearValue,
            branch_name: branchName,
            url: url,
            labels: labels.nodes.map(\.name).map(\.normalizedLinearValue),
            blocked_by: relations.nodes.compactMap { relation in
                guard let relatedIssue = relation.relatedIssue else {
                    return nil
                }

                return BlockerRef(
                    id: relatedIssue.id,
                    identifier: relatedIssue.identifier,
                    state: relatedIssue.state.name.normalizedLinearValue
                )
            },
            created_at: nil,
            updated_at: nil
        )
    }
}

private struct LinearState: Decodable {
    let name: String
}

private struct LinearLabels: Decodable {
    let nodes: [LinearLabel]
}

private struct LinearLabel: Decodable {
    let name: String
}

private struct LinearRelations: Decodable {
    let nodes: [LinearRelation]
}

private struct LinearRelation: Decodable {
    let relatedIssue: RelatedIssue?
}

private struct RelatedIssue: Decodable {
    let id: String
    let identifier: String
    let state: LinearState
}

private struct EncodableValue: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: Any) {
        switch value {
        case let string as String:
            encodeClosure = { encoder in
                var container = encoder.singleValueContainer()
                try container.encode(string)
            }
        case let int as Int:
            encodeClosure = { encoder in
                var container = encoder.singleValueContainer()
                try container.encode(int)
            }
        case let bool as Bool:
            encodeClosure = { encoder in
                var container = encoder.singleValueContainer()
                try container.encode(bool)
            }
        case let strings as [String]:
            encodeClosure = { encoder in
                var container = encoder.singleValueContainer()
                try container.encode(strings)
            }
        default:
            encodeClosure = { _ in
                let context = EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Unsupported GraphQL variable value: \(type(of: value))"
                )
                throw EncodingError.invalidValue(value, context)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

private extension String {
    var normalizedLinearValue: String {
        lowercased()
    }
}
