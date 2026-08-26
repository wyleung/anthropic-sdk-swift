import XCTest
@testable import Anthropic

final class PartialJSONTests: XCTestCase {
    func testParsesACompleteObject() throws {
        let value = try PartialJSON.parse(#"{"a":1,"b":"hi"}"#)
        XCTAssertEqual(value, .object(["a": .number(1), "b": .string("hi")]))
    }

    func testKeepsATruncatedTrailingStringValue() throws {
        let value = try PartialJSON.parse(#"{"name":"hel"#)
        XCTAssertEqual(value, .object(["name": .string("hel")]))
    }

    func testDropsATruncatedTrailingKeyEntirely() throws {
        let value = try PartialJSON.parse(#"{"a":1,"nam"#)
        XCTAssertEqual(value, .object(["a": .number(1)]))
    }

    func testDropsATruncatedTrailingNumberEntirely() throws {
        // Unlike strings, numbers have no closing delimiter of their own, so a buffer ending
        // right after a digit is ambiguous -- more digits could still be arriving. That whole
        // member is dropped rather than guessed at.
        let value = try PartialJSON.parse(#"{"a":1,"b":12"#)
        XCTAssertEqual(value, .object(["a": .number(1)]))
    }

    func testDropsATruncatedTrailingLiteralEntirely() throws {
        let value = try PartialJSON.parse(#"{"a":tru"#)
        XCTAssertEqual(value, .object([:]))
    }

    func testKeepsAPartiallyStreamedNestedArray() throws {
        let value = try PartialJSON.parse(#"{"a":[1,2,"#)
        XCTAssertEqual(value, .object(["a": .array([.number(1), .number(2)])]))
    }

    func testDropsAnIncompleteTrailingSurrogatePairEscape() throws {
        let value = try PartialJSON.parse(#"{"e":"\ud83d\ude"#)
        XCTAssertEqual(value, .object(["e": .string("")]))
    }

    func testParsesACompleteSurrogatePairEscape() throws {
        let value = try PartialJSON.parse(#"{"e":"😀"}"#)
        XCTAssertEqual(value, .object(["e": .string("😀")]))
    }

    func testThrowsResponseValidationOnMalformedInput() {
        XCTAssertThrowsError(try PartialJSON.parse("{not json")) { error in
            guard case AnthropicError.responseValidation = error else {
                return XCTFail("expected .responseValidation, got \(error)")
            }
        }
    }
}
