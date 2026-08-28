import XCTest
@testable import Anthropic

/// Regression coverage for adding `Role.system` alongside `.user`/`.assistant`.
final class RoleTests: XCTestCase {
    func testSystemEncodesToItsRawStringValue() throws {
        let data = try JSONEncoder().encode(Role.system)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"system\"")
    }

    func testSystemDecodesFromItsRawStringValue() throws {
        let role = try JSONDecoder().decode(Role.self, from: Data(#""system""#.utf8))
        XCTAssertEqual(role, .system)
    }
}
