import XCTest
import AnthropicBeta

/// Regression coverage for Fix #13: these 11 structs previously had no explicit `public init`, so
/// Swift only synthesized an *internal* memberwise init -- unconstructable from outside the
/// `AnthropicBeta` module. Deliberately using a non-`@testable` import here (unlike most tests in
/// this target) so a compile failure would actually catch a regression back to the internal-only
/// synthesized init.
final class BetaEnvironmentPublicInitTests: XCTestCase {
    func testBetaEnvironmentAndDeleteResponseArePubliclyConstructible() {
        let environment = BetaEnvironment(
            id: "env_01", config: .selfHosted(BetaSelfHostedConfig()), createdAt: "2026-01-15T00:00:00Z",
            metadata: [:], name: "My Env", updatedAt: "2026-01-15T00:00:00Z"
        )
        XCTAssertEqual(environment.type, "environment")

        let deleted = BetaEnvironmentDeleteResponse(id: "env_01")
        XCTAssertEqual(deleted.type, "environment_deleted")
    }

    func testCloudAndSelfHostedConfigArePubliclyConstructible() {
        let cloud = BetaCloudConfig(
            networking: .unrestricted(BetaUnrestrictedNetwork()), packages: BetaPackages(
                apt: [], cargo: [], gem: [], go: [], npm: [], pip: []
            )
        )
        XCTAssertEqual(cloud.type, "cloud")

        let selfHosted = BetaSelfHostedConfig()
        XCTAssertEqual(selfHosted.type, "self_hosted")
    }

    func testUnrestrictedAndLimitedNetworkArePubliclyConstructible() {
        let unrestricted = BetaUnrestrictedNetwork()
        XCTAssertEqual(unrestricted.type, "unrestricted")

        let limited = BetaLimitedNetwork(allowMcpServers: true, allowPackageManagers: false, allowedHosts: ["x.com"])
        XCTAssertEqual(limited.type, "limited")
    }

    func testPackagesIsPubliclyConstructible() {
        let packages = BetaPackages(apt: [], cargo: [], gem: [], go: [], npm: ["left-pad"], pip: [])
        XCTAssertEqual(packages.npm, ["left-pad"])
        XCTAssertNil(packages.type)
    }

    func testSelfHostedWorkAndSessionWorkDataArePubliclyConstructible() {
        let work = BetaSelfHostedWork(
            id: "work_01", createdAt: "2026-01-15T00:00:00Z", data: BetaSessionWorkData(id: "session_01"),
            environmentId: "env_01", metadata: [:], state: .queued
        )
        XCTAssertEqual(work.type, "work")
        XCTAssertEqual(work.data.type, "session")
    }

    func testSelfHostedWorkHeartbeatResponseIsPubliclyConstructible() {
        let heartbeat = BetaSelfHostedWorkHeartbeatResponse(
            lastHeartbeat: "2026-01-15T00:05:00Z", leaseExtended: true, state: .active, ttlSeconds: 30
        )
        XCTAssertEqual(heartbeat.type, "work_heartbeat")
    }

    func testSelfHostedWorkQueueStatsIsPubliclyConstructible() {
        let stats = BetaSelfHostedWorkQueueStats(depth: 3, pending: 1)
        XCTAssertEqual(stats.type, "work_queue_stats")
        XCTAssertNil(stats.oldestQueuedAt)
        XCTAssertNil(stats.workersPolling)
    }
}
