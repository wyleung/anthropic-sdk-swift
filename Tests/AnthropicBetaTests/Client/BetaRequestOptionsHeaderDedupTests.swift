import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// Regression coverage for Fix #12: `betaRequestOptions` must recognize a caller-supplied header
/// regardless of casing, instead of treating `Anthropic-Beta` and `anthropic-beta` as two distinct
/// dictionary keys (which `HTTPTransport.buildRequest`'s unordered header loop would then apply
/// non-deterministically).
final class BetaRequestOptionsHeaderDedupTests: XCTestCase {
    func testDifferentlyCasedAnthropicBetaHeaderIsNotDuplicated() {
        let options = RequestOptions(headers: ["Anthropic-Beta": "caller-flag-2026-01-01"])
        let merged = betaRequestOptions(betas: ["computed-flag-2026-01-01"], base: options)

        XCTAssertEqual(merged.headers.count, 1)
        XCTAssertEqual(merged.headers["Anthropic-Beta"] ?? nil, "caller-flag-2026-01-01")
        XCTAssertNil(merged.headers["anthropic-beta"] ?? nil)
    }

    func testDifferentlyCasedUserProfileIdHeaderIsNotDuplicated() {
        let options = RequestOptions(headers: ["Anthropic-User-Profile-Id": "caller-profile"])
        let merged = betaRequestOptions(betas: [], userProfileId: "computed-profile", base: options)

        XCTAssertEqual(merged.headers.count, 1)
        XCTAssertEqual(merged.headers["Anthropic-User-Profile-Id"] ?? nil, "caller-profile")
        XCTAssertNil(merged.headers["anthropic-user-profile-id"] ?? nil)
    }

    func testNoCallerHeaderStillComputesAnthropicBeta() {
        let merged = betaRequestOptions(betas: ["flag-a", "flag-b"], base: RequestOptions())
        XCTAssertEqual(merged.headers["anthropic-beta"] ?? nil, "flag-a,flag-b")
    }
}
