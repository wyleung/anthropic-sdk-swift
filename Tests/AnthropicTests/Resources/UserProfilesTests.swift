import XCTest
@testable import Anthropic

final class UserProfilesTests: XCTestCase {
    // Resources hold their client `unowned`, so it must outlive every call: a stored property, not a computed
    // one that would build (and immediately free) a fresh client on each access.
    private var client: AnthropicClient!

    override func setUp() {
        super.setUp()
        client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
    }

    override func tearDown() {
        MockURLProtocol.responder = nil
        client = nil
        super.tearDown()
    }

    private static let fullProfile = """
    {
        "id": "uprof_01ABC", "type": "user_profile", "created_at": "2026-10-01T00:00:00Z", "updated_at": "2026-10-02T00:00:00Z",
        "access_type": "application", "metadata": {"team": "growth"}, "name": "Ada Lovelace",
        "enforcement_status": "banned",
        "enforcement_actions": [
            {"type": "restriction", "id": "enac_1", "opened_at": "2026-10-01T00:00:00Z", "reason": "unsupported_region",
             "action": "verify", "expires_at": "2026-11-01T00:00:00Z"},
            {"type": "ban", "id": "enac_2", "opened_at": "2026-10-02T00:00:00Z", "reason": "fraud_or_abuse",
             "action": null, "expires_at": null}
        ],
        "external_user_details": {"account_status": "suspended", "country": "NL", "email_hash": "abc", "entity_type": "non_profit",
                                  "name_hash": "def", "onboarded_at": "2026-09-01T00:00:00Z", "reference_id": "row_9"},
        "programs": {
            "cyber": {"status": "active", "requirements": {"data_retention": true, "human_review": false},
                      "tiers": {"basic": {"status": "active"}, "advanced": {"status": "inactive"}}},
            "efs": {"status": "pending", "features": {"export": {"status": "inactive"}}}
        }
    }
    """

    private func respond(_ json: String, check: @escaping (URLRequest) -> Void = { _ in }) {
        MockURLProtocol.responder = { request in
            check(request)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
    }

    // MARK: - decoding

    func testRetrieveDecodesTheFullProfileWithEnforcementAndPrograms() async throws {
        var request: URLRequest?
        respond(Self.fullProfile) { request = $0 }
        let profile = try await client.userProfiles.retrieve("uprof_01ABC")

        XCTAssertEqual(request?.url?.path, "/v1/user_profiles/uprof_01ABC")
        XCTAssertEqual(profile.accessType, .application)
        XCTAssertEqual(profile.enforcementStatus, .banned)
        XCTAssertEqual(profile.name, "Ada Lovelace")

        let actions = try XCTUnwrap(profile.enforcementActions)
        guard case .restriction(let restriction) = actions[0], case .ban(let ban) = actions[1] else {
            return XCTFail("expected restriction then ban, got \(actions)")
        }
        XCTAssertEqual(restriction.reason, .unsupportedRegion)
        XCTAssertEqual(restriction.action, .verify)
        XCTAssertEqual(restriction.expiresAt, "2026-11-01T00:00:00Z")
        XCTAssertEqual(ban.reason, .fraudOrAbuse)
        XCTAssertNil(ban.action, "a ban cannot be cleared by the end user")
        XCTAssertNil(ban.expiresAt, "a ban has no end date")

        let details = try XCTUnwrap(profile.externalUserDetails)
        XCTAssertEqual(details.accountStatus, .suspended)
        XCTAssertEqual(details.entityType, .nonProfit)
        XCTAssertEqual(details.referenceId, "row_9")

        let cyber = try XCTUnwrap(profile.programs?.cyber)
        XCTAssertEqual(cyber.status, .active)
        XCTAssertEqual(cyber.requirements, UserProfileCyberRequirements(dataRetention: true, humanReview: false))
        XCTAssertEqual(cyber.tiers["advanced"]?.status, .inactive)
        XCTAssertEqual(profile.programs?.efs?.status, .pending)
        XCTAssertEqual(profile.programs?.efs?.features["export"]?.status, .inactive)
    }

    func testAProfileWithNoneOfTheNewFieldsStillDecodes() async throws {
        respond(#"{"id": "u", "type": "user_profile", "created_at": "t", "updated_at": "t", "metadata": {}}"#)
        let profile = try await client.userProfiles.retrieve("u")
        XCTAssertNil(profile.enforcementStatus)
        XCTAssertNil(profile.enforcementActions)
        XCTAssertNil(profile.programs)
        XCTAssertNil(profile.externalUserDetails)
    }

    func testEveryOpenEnumDegradesToUnknownInsteadOfFailingTheProfile() async throws {
        respond("""
        {"id": "u", "type": "user_profile", "created_at": "t", "updated_at": "t", "metadata": {},
         "access_type": "delegated", "enforcement_status": "suspended_pending_review",
         "enforcement_actions": [
            {"type": "restriction", "id": "e1", "opened_at": "t", "reason": "novel_reason", "action": "call_us"},
            {"type": "quarantine", "id": "e2"}],
         "external_user_details": {"account_status": "dormant", "entity_type": "dao"},
         "programs": {"cyber": {"status": "revoked", "tiers": {"x": {"status": "paused"}}}}}
        """)
        let profile = try await client.userProfiles.retrieve("u")
        XCTAssertEqual(profile.accessType, .unknown("delegated"))
        XCTAssertEqual(profile.enforcementStatus, .unknown("suspended_pending_review"))
        let actions = try XCTUnwrap(profile.enforcementActions)
        guard case .restriction(let restriction) = actions[0] else { return XCTFail("restriction") }
        XCTAssertEqual(restriction.reason, .unknown("novel_reason"))
        XCTAssertEqual(restriction.action, .unknown("call_us"))
        guard case .unknown(let type, _) = actions[1] else { return XCTFail("expected an unknown action") }
        XCTAssertEqual(type, "quarantine")
        XCTAssertEqual(profile.externalUserDetails?.accountStatus, .unknown("dormant"))
        XCTAssertEqual(profile.externalUserDetails?.entityType, .unknown("dao"))
        XCTAssertEqual(profile.programs?.cyber?.status, .unknown("revoked"))
        XCTAssertEqual(profile.programs?.cyber?.tiers["x"]?.status, .unknown("paused"))
    }

    func testEnforcementStatusAndReasonRoundTripTheirWireValues() throws {
        func wire<T: Encodable>(_ value: T) throws -> String {
            let data = try JSONEncoder().encode([value])
            return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String]).first ?? ""
        }
        XCTAssertEqual(try wire(UserProfileEnforcementActionReason.accountCompromise), "account_compromise")
        XCTAssertEqual(try wire(UserProfileEnforcementActionReason.usagePolicyViolation), "usage_policy_violation")
        XCTAssertEqual(try wire(UserProfileEnforcementStatus.unrestricted), "unrestricted")
        XCTAssertEqual(try wire(UserProfileExternalUserEntityType.nonProfit), "non_profit")
    }

    // MARK: - requests

    func testGARequestsCarryNoBetaHeaderAndNoBetaQueryFlag() async throws {
        var request: URLRequest?
        respond(Self.fullProfile) { request = $0 }
        _ = try await client.userProfiles.retrieve("uprof_01ABC")
        XCTAssertNil(request?.value(forHTTPHeaderField: "anthropic-beta"))
        XCTAssertNil(request?.url?.query)
    }

    func testCreateSendsTheCurrentBodyShape() async throws {
        var body: [String: Any] = [:]
        respond(Self.fullProfile) { request in
            body = (bodyData(from: request).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/user_profiles")
        }
        _ = try await client.userProfiles.create(UserProfileCreateParams(
            accessType: .passthrough,
            externalUserDetails: UserProfileExternalUserDetailsParams(
                accountStatus: .active, entityType: .nonProfit, onboardedAt: "2026-09-01T00:00:00Z", referenceId: "row_9"
            ),
            metadata: ["team": "growth"], name: "Acme"
        ))
        XCTAssertEqual(body["access_type"] as? String, "passthrough")
        XCTAssertEqual(body["name"] as? String, "Acme")
        let details = try XCTUnwrap(body["external_user_details"] as? [String: Any])
        XCTAssertEqual(details["entity_type"] as? String, "non_profit")
        XCTAssertEqual(details["account_status"] as? String, "active")
        XCTAssertEqual(details["onboarded_at"] as? String, "2026-09-01T00:00:00Z")
        XCTAssertEqual(details["reference_id"] as? String, "row_9")
        XCTAssertNil(details["country"], "unset detail fields are omitted, never null: null is rejected on update")
    }

    func testCreateWithNoArgumentsSendsAnEmptyBody() async throws {
        var body: [String: Any]?
        respond(Self.fullProfile) { body = (bodyData(from: $0).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) }
        _ = try await client.userProfiles.create()
        XCTAssertEqual(body?.count, 0)
    }

    func testUpdateOmitsEverythingNotGivenSoItLeavesThoseFieldsUnchanged() async throws {
        var body: [String: Any] = [:]
        respond(Self.fullProfile) { request in
            body = (bodyData(from: request).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
            XCTAssertEqual(request.url?.path, "/v1/user_profiles/uprof_01ABC")
        }
        _ = try await client.userProfiles.update("uprof_01ABC", UserProfileUpdateParams(metadata: ["old_key": ""]))
        XCTAssertEqual(Set(body.keys), ["metadata"])
        XCTAssertEqual((body["metadata"] as? [String: String])?["old_key"], "", "an empty string is how a key is removed")
    }

    func testListSendsEnforcementStatusAsBracketedItemsAndTheOrderingParams() async throws {
        var query: [URLQueryItem] = []
        respond(#"{"data": [], "next_page": "cursor-2"}"#) { query = URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?.queryItems ?? [] }
        let page = try await client.userProfiles.list(
            enforcementStatus: ["banned", "restricted"], limit: 25, order: "desc", orderBy: "name", page: "cursor-1"
        )
        XCTAssertEqual(page.nextPage, "cursor-2")
        XCTAssertEqual(query.filter { $0.name == "enforcement_status[]" }.compactMap(\.value), ["banned", "restricted"])
        XCTAssertTrue(query.contains(URLQueryItem(name: "limit", value: "25")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "order", value: "desc")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "order_by", value: "name")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "page", value: "cursor-1")))
    }

    func testListOmitsTheFilterWhenNotGiven() async throws {
        var query: [URLQueryItem]?
        respond(#"{"data": [], "next_page": null}"#) { query = URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?.queryItems }
        _ = try await client.userProfiles.list()
        XCTAssertTrue(query == nil || query?.isEmpty == true)
    }

    func testDeleteDecodesTheTombstone() async throws {
        var request: URLRequest?
        respond(#"{"id": "uprof_01ABC", "type": "user_profile_deleted"}"#) { request = $0 }
        let deleted = try await client.userProfiles.delete("uprof_01ABC")
        XCTAssertEqual(request?.httpMethod, "DELETE")
        XCTAssertEqual(deleted.id, "uprof_01ABC")
    }

    func testActionURLsCreatePostsTheEnrollAction() async throws {
        var request: URLRequest?
        respond(#"{"expires_at": "2026-11-01T00:00:00Z", "type": "user_profile_action_url", "url": "https://x.example/enroll"}"#) { request = $0 }
        let action = try await client.userProfiles.actionURLs.create("uprof_01ABC")
        XCTAssertEqual(request?.url?.path, "/v1/user_profiles/uprof_01ABC/action_urls")
        XCTAssertEqual(action.url, "https://x.example/enroll")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.flatMap(bodyData(from:)))) as? [String: Any])
        XCTAssertEqual(body["action"] as? NSDictionary, ["type": "enroll_end_user"])
    }

    func testAnEmptyUserProfileIdIsRejectedBeforeAnyRequest() async throws {
        var sent = 0
        respond("{}") { _ in sent += 1 }
        do {
            _ = try await client.userProfiles.retrieve("")
            XCTFail("expected invalidArgument")
        } catch AnthropicError.invalidArgument {
            XCTAssertEqual(sent, 0)
        }
    }
}
