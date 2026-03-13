import Foundation
import XCTest
@testable import SymphonyCore

final class BlockerRefTests: XCTestCase {
    func test_blockerRef_whenDecodedFromJSON_supportsOptionalFields() throws {
        let blockerRef = BlockerRef(id: nil, identifier: "DB-10", state: nil)

        let encoded = try JSONEncoder().encode(blockerRef)
        let decoded = try JSONDecoder().decode(BlockerRef.self, from: encoded)

        XCTAssertEqual(decoded, blockerRef)
    }
}
