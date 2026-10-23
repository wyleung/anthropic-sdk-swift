import XCTest
@testable import Anthropic

/// Like `XCTAssertThrowsError`, but the error must be one of the credential-loading failures
/// (`AnthropicError.credentials` / `.identityTokenFile`), not merely any error. Those used to be thrown
/// as `.responseValidation`, which means "the server sent something unusable" -- a different thing for a
/// caller deciding whether to fix a config file or retry a request.
func XCTAssertThrowsCredentialsError<T>(
    _ expression: @autoclosure () throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
        guard let error = error as? AnthropicError, error.isCredentialsError else {
            return XCTFail("expected a credentials error, got \(error)", file: file, line: line)
        }
    }
}
