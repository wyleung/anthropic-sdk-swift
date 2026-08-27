import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaUserProfilesTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let profileFixture = """
    {
        "id": "uprof_01ABC",
        "created_at": "2026-01-15T00:00:00Z",
        "metadata": {},
        "trust_grants": {},
        "type": "user_profile",
        "updated_at": "2026-01-15T00:00:00Z",
        "access_type": null,
        "external_id": null,
        "name": null,
        "relationship": "external"
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testCreateSendsProvidedBodyFieldsAndBetaHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/user_profiles")
            return self.jsonResponse(Self.profileFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let profile = try await client.beta.userProfiles.create(
            BetaUserProfileCreateParams(relationship: .external)
        )
        XCTAssertEqual(profile.id, "uprof_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "user-profiles-2026-08-18")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["relationship"] as? String, "external")
        XCTAssertNil(json["name"])
    }

    func testCreateWithNoArgumentsSendsEmptyBody() async throws {
        MockURLProtocol.responder = { request in
            let body = bodyData(from: request) ?? Data()
            let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            XCTAssertEqual(json?.count ?? 0, 0)
            return self.jsonResponse(Self.profileFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.userProfiles.create()
    }

    func testRetrieveDecodesProfile() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/user_profiles/uprof_01ABC")
            return self.jsonResponse(Self.profileFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let profile = try await client.beta.userProfiles.retrieve("uprof_01ABC")
        XCTAssertEqual(profile.relationship, .external)
    }

    func testUpdatePostsPatchBody() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/user_profiles/uprof_01ABC")
            let body = bodyData(from: request) ?? Data()
            let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            XCTAssertEqual(json?["name"] as? String, "New Name")
            return self.jsonResponse(Self.profileFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.userProfiles.update("uprof_01ABC", BetaUserProfileUpdateParams(name: "New Name"))
    }

    func testListSendsFlatQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.profileFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/user_profiles")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(query.contains(URLQueryItem(name: "limit", value: "10")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "order", value: "asc")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.userProfiles.list(limit: 10, order: "asc")
        XCTAssertEqual(page.data.count, 1)
    }

    func testCreateEnrollmentUrlPostsToEnrollmentUrlPath() async throws {
        let fixture = """
        {"expires_at": "2026-02-01T00:00:00Z", "type": "enrollment_url", "url": "https://claude.ai/enroll/x"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/user_profiles/uprof_01ABC/enrollment_url")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let enrollment = try await client.beta.userProfiles.createEnrollmentUrl("uprof_01ABC")
        XCTAssertEqual(enrollment.url, "https://claude.ai/enroll/x")
    }
}
