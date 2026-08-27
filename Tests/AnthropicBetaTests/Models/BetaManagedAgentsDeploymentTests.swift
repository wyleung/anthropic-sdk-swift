import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaManagedAgentsDeploymentTests: XCTestCase {
    private static let fullFixture = """
    {
        "id": "deploy_01ABC",
        "agent": {"id": "agent_01ABC", "type": "agent", "version": 2},
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "description": "nightly triage",
        "environment_id": "env_01ABC",
        "initial_events": [
            {"content": [{"text": "hello", "type": "text"}], "type": "user.message"},
            {
                "description": "triage the queue",
                "rubric": {"content": "must close 3 tickets", "type": "text"},
                "type": "user.define_outcome",
                "max_iterations": 5
            },
            {"content": [{"text": "be terse", "type": "text"}], "type": "system.message"}
        ],
        "metadata": {"team": "platform"},
        "name": "Nightly Triage",
        "paused_reason": {
            "error": {"type": "vault_archived_error"},
            "type": "error"
        },
        "resources": [
            {"file_id": "file_01ABC", "type": "file", "mount_path": "/mnt/data"},
            {"memory_store_id": "ms_01ABC", "type": "memory_store", "access": "read_write", "instructions": "use it"},
            {"type": "github_repository", "url": "https://github.com/example/repo", "checkout": null, "mount_path": null}
        ],
        "schedule": {
            "expression": "0 * * * *",
            "timezone": "UTC",
            "type": "cron",
            "last_run_at": "2026-01-15T01:00:00Z",
            "upcoming_runs_at": ["2026-01-15T02:00:00Z"]
        },
        "status": "paused",
        "type": "deployment",
        "updated_at": "2026-01-15T01:00:00Z",
        "vault_ids": ["vault_01ABC"],
        "budget": {"max_list_cost": {"amount": "10.00", "currency": "USD"}, "type": "limit"}
    }
    """.data(using: .utf8)!

    func testDecodesFullDeploymentFixture() throws {
        let deployment = try HTTPTransport.decoder.decode(BetaManagedAgentsDeployment.self, from: Self.fullFixture)

        XCTAssertEqual(deployment.id, "deploy_01ABC")
        XCTAssertEqual(deployment.agent.version, 2)
        XCTAssertEqual(deployment.status, .paused)
        XCTAssertEqual(deployment.vaultIds, ["vault_01ABC"])
        XCTAssertEqual(deployment.budget?.maxListCost.currency, .usd)

        XCTAssertEqual(deployment.schedule?.lastRunAt, "2026-01-15T01:00:00Z")
        XCTAssertEqual(deployment.schedule?.upcomingRunsAt, ["2026-01-15T02:00:00Z"])

        guard case .error(let errorReason) = deployment.pausedReason else {
            return XCTFail("Expected an error paused reason")
        }
        guard case .vaultArchived = errorReason.error else {
            return XCTFail("Expected a vaultArchived paused-reason error")
        }

        XCTAssertEqual(deployment.initialEvents.count, 3)
        guard case .userMessage(let userMessage) = deployment.initialEvents[0] else {
            return XCTFail("Expected a userMessage initial event")
        }
        guard case .text(let block) = userMessage.content[0] else {
            return XCTFail("Expected a text content block")
        }
        XCTAssertEqual(block.text, "hello")

        guard case .userDefineOutcome(let outcome) = deployment.initialEvents[1] else {
            return XCTFail("Expected a userDefineOutcome initial event")
        }
        XCTAssertEqual(outcome.maxIterations, 5)
        guard case .text(let rubric) = outcome.rubric else {
            return XCTFail("Expected a text rubric")
        }
        XCTAssertEqual(rubric.content, "must close 3 tickets")

        guard case .systemMessage(let system) = deployment.initialEvents[2] else {
            return XCTFail("Expected a systemMessage initial event")
        }
        XCTAssertEqual(system.content[0].text, "be terse")

        XCTAssertEqual(deployment.resources.count, 3)
        guard case .file(let file) = deployment.resources[0] else {
            return XCTFail("Expected a file resource config")
        }
        XCTAssertEqual(file.mountPath, "/mnt/data")
        guard case .memoryStore(let memoryStore) = deployment.resources[1] else {
            return XCTFail("Expected a memoryStore resource config")
        }
        XCTAssertEqual(memoryStore.access, .readWrite)
        guard case .githubRepository(let repo) = deployment.resources[2] else {
            return XCTFail("Expected a githubRepository resource config")
        }
        XCTAssertNil(repo.checkout)
        XCTAssertEqual(repo.url, "https://github.com/example/repo")
    }

    func testGithubRepositoryResourceConfigDecodesBranchAndCommitCheckouts() throws {
        let branchFixture = """
        {"type": "github_repository", "url": "https://github.com/a/b", "checkout": {"name": "main", "type": "branch"}}
        """.data(using: .utf8)!
        let commitFixture = """
        {"type": "github_repository", "url": "https://github.com/a/b", "checkout": {"sha": "abc123", "type": "commit"}}
        """.data(using: .utf8)!

        let branchConfig = try HTTPTransport.decoder.decode(BetaManagedAgentsGitHubRepositoryResourceConfig.self, from: branchFixture)
        guard case .branch(let branch) = branchConfig.checkout else {
            return XCTFail("Expected a branch checkout")
        }
        XCTAssertEqual(branch.name, "main")

        let commitConfig = try HTTPTransport.decoder.decode(BetaManagedAgentsGitHubRepositoryResourceConfig.self, from: commitFixture)
        guard case .commit(let commit) = commitConfig.checkout else {
            return XCTFail("Expected a commit checkout")
        }
        XCTAssertEqual(commit.sha, "abc123")
    }

    func testSessionResourceConfigUnionDecodesUnknownVariant() throws {
        let fixture = """
        {"type": "future_resource", "foo": "bar"}
        """.data(using: .utf8)!
        let config = try HTTPTransport.decoder.decode(BetaManagedAgentsSessionResourceConfig.self, from: fixture)
        guard case .unknown(let type, _) = config else {
            return XCTFail("Expected an unknown resource config")
        }
        XCTAssertEqual(type, "future_resource")
    }

    // MARK: - DeploymentPausedReasonError (14 variants + unknown)

    private static let pausedReasonErrorTypes: [(String, Any.Type)] = [
        ("environment_archived_error", BetaManagedAgentsEnvironmentArchivedDeploymentPausedReasonError.self),
        ("agent_archived_error", BetaManagedAgentsAgentArchivedDeploymentPausedReasonError.self),
        ("environment_not_found_error", BetaManagedAgentsEnvironmentNotFoundDeploymentPausedReasonError.self),
        ("vault_not_found_error", BetaManagedAgentsVaultNotFoundDeploymentPausedReasonError.self),
        ("file_not_found_error", BetaManagedAgentsFileNotFoundDeploymentPausedReasonError.self),
        ("session_resource_not_found_error", BetaManagedAgentsSessionResourceNotFoundDeploymentPausedReasonError.self),
        ("workspace_archived_error", BetaManagedAgentsWorkspaceArchivedDeploymentPausedReasonError.self),
        ("organization_disabled_error", BetaManagedAgentsOrganizationDisabledDeploymentPausedReasonError.self),
        ("memory_store_archived_error", BetaManagedAgentsMemoryStoreArchivedDeploymentPausedReasonError.self),
        ("skill_not_found_error", BetaManagedAgentsSkillNotFoundDeploymentPausedReasonError.self),
        ("vault_archived_error", BetaManagedAgentsVaultArchivedDeploymentPausedReasonError.self),
        ("unknown_error", BetaManagedAgentsUnknownDeploymentPausedReasonError.self),
        ("self_hosted_resources_unsupported_error", BetaManagedAgentsSelfHostedResourcesUnsupportedDeploymentPausedReasonError.self),
        ("mcp_egress_blocked_error", BetaManagedAgentsMCPEgressBlockedDeploymentPausedReasonError.self),
    ]

    func testDeploymentPausedReasonErrorDecodesAllFourteenVariants() throws {
        for (type, _) in Self.pausedReasonErrorTypes {
            let fixture = "{\"type\": \"\(type)\"}".data(using: .utf8)!
            let error = try HTTPTransport.decoder.decode(BetaManagedAgentsDeploymentPausedReasonError.self, from: fixture)
            let encoded = try HTTPTransport.encoder.encode(error)
            let roundTripped = try HTTPTransport.decoder.decode(BetaManagedAgentsDeploymentPausedReasonError.self, from: encoded)
            XCTAssertEqual(error, roundTripped, "round trip failed for \(type)")

            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            XCTAssertEqual(json["type"] as? String, type)
        }
        XCTAssertEqual(Self.pausedReasonErrorTypes.count, 14)
    }

    func testDeploymentPausedReasonErrorDecodesUnknownVariant() throws {
        let fixture = """
        {"type": "some_future_error"}
        """.data(using: .utf8)!
        let error = try HTTPTransport.decoder.decode(BetaManagedAgentsDeploymentPausedReasonError.self, from: fixture)
        guard case .unknown(let type, _) = error else {
            return XCTFail("Expected an unknown paused-reason error")
        }
        XCTAssertEqual(type, "some_future_error")
    }

    // MARK: - DeploymentCreateParams / DeploymentUpdateParams encoding

    func testCreateParamsEncodesBareAgentIdString() throws {
        let params = BetaDeploymentCreateParams(
            agent: "agent_01ABC",
            environmentId: "env_01ABC",
            initialEvents: [.userMessage(BetaManagedAgentsUserMessageEventParams(content: [.text(BetaManagedAgentsTextBlockParam(text: "hi"))]))],
            name: "My Deployment"
        )
        let data = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["agent"] as? String, "agent_01ABC")
        XCTAssertNil(json["resources"])
        XCTAssertNil(json["schedule"])
        XCTAssertNil(json["vault_ids"])
    }

    func testCreateParamsEncodesExplicitAgentObject() throws {
        let params = BetaDeploymentCreateParams(
            agent: .agent(BetaManagedAgentsAgentParams(id: "agent_01ABC", version: 3)),
            environmentId: "env_01ABC",
            initialEvents: [],
            name: "My Deployment"
        )
        let data = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let agent = try XCTUnwrap(json["agent"] as? [String: Any])
        XCTAssertEqual(agent["id"] as? String, "agent_01ABC")
        XCTAssertEqual(agent["version"] as? Int, 3)
    }

    func testUpdateParamsOmittedFieldsAreNotSent() throws {
        let params = BetaDeploymentUpdateParams(name: "Renamed")
        let data = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "Renamed")
        XCTAssertNil(json["resources"])
        XCTAssertNil(json["vault_ids"])
        XCTAssertNil(json["metadata"])
        XCTAssertNil(json["agent"])
    }

    func testUpdateParamsResourcesAndVaultIdsAcceptNilAndEmptyArray() throws {
        let clearingParams = BetaDeploymentUpdateParams(resources: [], vaultIds: [])
        let clearingData = try HTTPTransport.encoder.encode(clearingParams)
        let clearingJson = try XCTUnwrap(JSONSerialization.jsonObject(with: clearingData) as? [String: Any])
        XCTAssertEqual((clearingJson["resources"] as? [Any])?.count, 0)
        XCTAssertEqual((clearingJson["vault_ids"] as? [Any])?.count, 0)

        let populatedParams = BetaDeploymentUpdateParams(
            resources: [.file(BetaManagedAgentsFileResourceParams(fileId: "file_01ABC"))],
            vaultIds: ["vault_01ABC"]
        )
        let populatedData = try HTTPTransport.encoder.encode(populatedParams)
        let populatedJson = try XCTUnwrap(JSONSerialization.jsonObject(with: populatedData) as? [String: Any])
        XCTAssertEqual((populatedJson["resources"] as? [Any])?.count, 1)
        XCTAssertEqual(populatedJson["vault_ids"] as? [String], ["vault_01ABC"])
    }

    func testUpdateParamsMetadataPatchesPerKey() throws {
        let params = BetaDeploymentUpdateParams(metadata: ["old_key": nil, "new_key": "value"])
        let data = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertTrue(metadata["old_key"] is NSNull)
        XCTAssertEqual(metadata["new_key"] as? String, "value")
    }
}
