import Foundation
import XCTest
@testable import SymphonyCore

final class LinearClientTests: XCTestCase {
    override func tearDown() {
        LinearURLProtocolMock.handler = nil
        super.tearDown()
    }

    func test_fetchActiveIssues_whenResponseIsSuccessful_returnsNormalizedIssues() async throws {
        let session = makeSession()
        let endpoint = URL(string: "https://linear.test/graphql")!
        LinearURLProtocolMock.handler = { request in
            XCTAssertEqual(request.url, endpoint)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "test-key")

            let body = try XCTUnwrap(httpBody(from: request))
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(payload["variables"] as? [String: AnyHashable], [
                "teamSlug": "backend",
                "states": ["Todo", "In Progress"],
            ])

            let responseBody = """
            {
              "data": {
                "issues": {
                  "nodes": [
                    {
                      "id": "issue-1",
                      "identifier": "DB-188",
                      "title": "Build Linear client",
                      "description": "Create GraphQL integration",
                      "priority": 1,
                      "state": { "name": "In Progress" },
                      "branchName": "kai/db-188-linear-client",
                      "url": "https://linear.app/issue/DB-188",
                      "labels": {
                        "nodes": [
                          { "name": "Backend" },
                          { "name": "Swift" }
                        ]
                      },
                      "relations": {
                        "nodes": [
                          {
                            "relatedIssue": {
                              "id": "issue-2",
                              "identifier": "DB-100",
                              "state": { "name": "Done" }
                            }
                          }
                        ]
                      }
                    }
                  ]
                }
              }
            }
            """

            return try makeResponse(
                url: endpoint,
                statusCode: 200,
                body: responseBody
            )
        }

        let client = LinearClient(apiKey: "test-key", endpoint: endpoint, session: session)

        let issues = try await client.fetchActiveIssues(
            teamSlug: "backend",
            states: ["Todo", "In Progress"]
        )

        XCTAssertEqual(issues, [
            Issue(
                id: "issue-1",
                identifier: "DB-188",
                title: "Build Linear client",
                description: "Create GraphQL integration",
                priority: 1,
                state: "in progress",
                branch_name: "kai/db-188-linear-client",
                url: "https://linear.app/issue/DB-188",
                labels: ["backend", "swift"],
                blocked_by: [
                    BlockerRef(id: "issue-2", identifier: "DB-100", state: "done")
                ],
                created_at: nil,
                updated_at: nil
            )
        ])
    }

    func test_fetchIssueStates_whenResponseIsSuccessful_returnsLowercasedStateMap() async throws {
        let session = makeSession()
        let endpoint = URL(string: "https://linear.test/graphql")!
        LinearURLProtocolMock.handler = { _ in
            let responseBody = """
            {
              "data": {
                "issues": {
                  "nodes": [
                    {
                      "id": "issue-1",
                      "state": { "name": "Done" }
                    },
                    {
                      "id": "issue-2",
                      "state": { "name": "Canceled" }
                    }
                  ]
                }
              }
            }
            """

            return try makeResponse(
                url: endpoint,
                statusCode: 200,
                body: responseBody
            )
        }

        let client = LinearClient(apiKey: "test-key", endpoint: endpoint, session: session)

        let states = try await client.fetchIssueStates(ids: ["issue-1", "issue-2"])

        XCTAssertEqual(states, [
            "issue-1": "done",
            "issue-2": "canceled",
        ])
    }

    func test_fetchTerminalIssues_whenResponseIsSuccessful_returnsIssues() async throws {
        let session = makeSession()
        let endpoint = URL(string: "https://linear.test/graphql")!
        LinearURLProtocolMock.handler = { _ in
            let responseBody = """
            {
              "data": {
                "issues": {
                  "nodes": [
                    {
                      "id": "issue-3",
                      "identifier": "DB-189",
                      "title": "Clean startup state",
                      "description": null,
                      "priority": null,
                      "state": { "name": "Done" },
                      "branchName": null,
                      "url": null,
                      "labels": { "nodes": [] },
                      "relations": { "nodes": [] }
                    }
                  ]
                }
              }
            }
            """

            return try makeResponse(
                url: endpoint,
                statusCode: 200,
                body: responseBody
            )
        }

        let client = LinearClient(apiKey: "test-key", endpoint: endpoint, session: session)

        let issues = try await client.fetchTerminalIssues(teamSlug: "backend", states: ["Done"])

        XCTAssertEqual(issues.map(\.state), ["done"])
        XCTAssertEqual(issues.map(\.identifier), ["DB-189"])
    }

    func test_fetchActiveIssues_whenStatusCodeIsNon200_throwsHttpError() async {
        let session = makeSession()
        let endpoint = URL(string: "https://linear.test/graphql")!
        LinearURLProtocolMock.handler = { _ in
            try makeResponse(url: endpoint, statusCode: 503, body: "{}")
        }

        let client = LinearClient(apiKey: "test-key", endpoint: endpoint, session: session)

        await XCTAssertThrowsErrorAsync(
            try await client.fetchActiveIssues(teamSlug: "backend", states: ["Todo"])
        ) { error in
            XCTAssertEqual(error as? LinearClientError, .httpError(503))
        }
    }

    func test_fetchActiveIssues_whenGraphQLErrorsArePresent_throwsApiError() async {
        let session = makeSession()
        let endpoint = URL(string: "https://linear.test/graphql")!
        LinearURLProtocolMock.handler = { _ in
            let responseBody = """
            {
              "errors": [
                { "message": "Query failed" }
              ]
            }
            """

            return try makeResponse(url: endpoint, statusCode: 200, body: responseBody)
        }

        let client = LinearClient(apiKey: "test-key", endpoint: endpoint, session: session)

        await XCTAssertThrowsErrorAsync(
            try await client.fetchActiveIssues(teamSlug: "backend", states: ["Todo"])
        ) { error in
            XCTAssertEqual(error as? LinearClientError, .apiError("Query failed"))
        }
    }

    func test_fetchActiveIssues_whenResponseCannotDecode_throwsDecodingError() async {
        let session = makeSession()
        let endpoint = URL(string: "https://linear.test/graphql")!
        LinearURLProtocolMock.handler = { _ in
            let responseBody = """
            {
              "data": {
                "issues": {
                  "nodes": [
                    {
                      "id": 1
                    }
                  ]
                }
              }
            }
            """

            return try makeResponse(url: endpoint, statusCode: 200, body: responseBody)
        }

        let client = LinearClient(apiKey: "test-key", endpoint: endpoint, session: session)

        await XCTAssertThrowsErrorAsync(
            try await client.fetchActiveIssues(teamSlug: "backend", states: ["Todo"])
        ) { error in
            guard case .decodingError = error as? LinearClientError else {
                return XCTFail("Expected decodingError, got \(error)")
            }
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LinearURLProtocolMock.self]
        return URLSession(configuration: configuration)
    }
}

private final class LinearURLProtocolMock: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeResponse(
    url: URL,
    statusCode: Int,
    body: String
) throws -> (HTTPURLResponse, Data) {
    let response = try XCTUnwrap(
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
    )
    let data = Data(body.utf8)
    return (response, data)
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown")
    } catch {
        errorHandler(error)
    }
}

private func httpBody(from request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    let bufferSize = 1024
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: bufferSize)

    while stream.hasBytesAvailable {
        let bytesRead = stream.read(&buffer, maxLength: bufferSize)
        if bytesRead < 0 {
            return nil
        }
        if bytesRead == 0 {
            break
        }

        data.append(buffer, count: bytesRead)
    }

    return data
}
