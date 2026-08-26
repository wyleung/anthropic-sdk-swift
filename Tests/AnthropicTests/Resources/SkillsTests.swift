import XCTest
@testable import Anthropic

final class SkillsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let skillFixture = """
    {
        "id": "skill_01ABC",
        "created_at": "2026-01-15T00:00:00Z",
        "display_name": "PDF Summarizer",
        "latest_version_id": "skillver_01ABC",
        "source": {"type": "custom"},
        "type": "skill",
        "updated_at": "2026-01-15T00:00:00Z"
    }
    """.data(using: .utf8)!

    private static let skillVersionFixture = """
    {
        "id": "skillver_01ABC",
        "created_at": "2026-01-15T00:00:00Z",
        "description": "Summarizes PDFs",
        "name": "pdf-summarizer",
        "skill_id": "skill_01ABC",
        "type": "skill_version"
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: 200, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    // MARK: - SkillSource decode

    func testSkillDecodesKnownSourceKinds() throws {
        for (raw, expected) in [
            ("custom", SkillSource.Kind.custom),
            ("anthropic", .anthropic),
            ("anthropic_example", .anthropicExample),
            ("plugin", .plugin),
        ] {
            let json = String(data: Self.skillFixture, encoding: .utf8)!
                .replacingOccurrences(of: "\"custom\"", with: "\"\(raw)\"")
                .data(using: .utf8)!
            let skill = try HTTPTransport.decoder.decode(Skill.self, from: json)
            XCTAssertEqual(skill.source.type, expected)
        }
    }

    func testSkillSourceFallsBackToUnknownForUnrecognizedKind() throws {
        let json = String(data: Self.skillFixture, encoding: .utf8)!
            .replacingOccurrences(of: "\"custom\"", with: "\"future_kind\"")
            .data(using: .utf8)!
        let skill = try HTTPTransport.decoder.decode(Skill.self, from: json)
        XCTAssertEqual(skill.source.type, .unknown("future_kind"))
    }

    // MARK: - Skills resource

    func testSkillsCreateSendsMultipartFilesAndDisplayName() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/skills")
            XCTAssertEqual(request.httpMethod, "POST")
            return self.jsonResponse(Self.skillFixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let skill = try await client.skills.create(
            files: [
                SkillFileUpload(
                    filename: "SKILL.md", contentType: "text/markdown", data: Data("# Skill".utf8)
                ),
                SkillFileUpload(
                    filename: "helper.py", contentType: "text/x-python", data: Data("print(1)".utf8)
                ),
            ],
            displayName: "PDF Summarizer"
        )
        XCTAssertEqual(skill.id, "skill_01ABC")
        XCTAssertEqual(skill.source.type, .custom)

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let bodyString = try XCTUnwrap(String(data: body, encoding: .utf8))

        XCTAssertEqual(bodyString.components(separatedBy: "name=\"files\"").count - 1, 2)
        XCTAssertTrue(bodyString.contains("filename=\"SKILL.md\""))
        XCTAssertTrue(bodyString.contains("filename=\"helper.py\""))
        XCTAssertTrue(bodyString.contains("name=\"display_name\""))
        XCTAssertTrue(bodyString.contains("PDF Summarizer"))
    }

    func testSkillsRetrieveDecodesSkill() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/skills/skill_01ABC")
            return self.jsonResponse(Self.skillFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let skill = try await client.skills.retrieve("skill_01ABC")
        XCTAssertEqual(skill.displayName, "PDF Summarizer")
    }

    func testSkillsListSendsQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.skillFixture, encoding: .utf8)!)], "next_page": "cursor-2"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/skills")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first { $0.name == "source" }?.value, "custom")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.skills.list(source: "custom")
        XCTAssertEqual(page.nextPage, "cursor-2")
    }

    func testSkillsDeleteDecodesDeletedSkill() async throws {
        let fixture = """
        {"id": "skill_01ABC", "type": "skill_deleted"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/skills/skill_01ABC")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.skills.delete("skill_01ABC")
        XCTAssertEqual(deleted.type, "skill_deleted")
    }

    // MARK: - Skills.Versions resource

    func testVersionsCreateSendsMultipartFilesScopedBySkillId() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/skills/skill_01ABC/versions")
            XCTAssertEqual(request.httpMethod, "POST")
            return self.jsonResponse(Self.skillVersionFixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let version = try await client.skills.versions.create(
            skillId: "skill_01ABC",
            files: [SkillFileUpload(filename: "SKILL.md", contentType: "text/markdown", data: Data("# v2".utf8))]
        )
        XCTAssertEqual(version.id, "skillver_01ABC")
        XCTAssertEqual(version.skillId, "skill_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let bodyString = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(bodyString.contains("filename=\"SKILL.md\""))
    }

    func testVersionsRetrieveAcceptsLatestSentinel() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/skills/skill_01ABC/versions/latest")
            return self.jsonResponse(Self.skillVersionFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let version = try await client.skills.versions.retrieve("latest", skillId: "skill_01ABC")
        XCTAssertEqual(version.name, "pdf-summarizer")
    }

    func testVersionsListSendsPaginationParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.skillVersionFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/skills/skill_01ABC/versions")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first { $0.name == "limit" }?.value, "5")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.skills.versions.list(skillId: "skill_01ABC", limit: 5)
        XCTAssertEqual(page.data.count, 1)
    }

    func testVersionsDeleteDecodesDeletedSkillVersion() async throws {
        let fixture = """
        {"id": "skillver_01ABC", "type": "skill_version_deleted"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/skills/skill_01ABC/versions/skillver_01ABC")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.skills.versions.delete("skillver_01ABC", skillId: "skill_01ABC")
        XCTAssertEqual(deleted.type, "skill_version_deleted")
    }
}
