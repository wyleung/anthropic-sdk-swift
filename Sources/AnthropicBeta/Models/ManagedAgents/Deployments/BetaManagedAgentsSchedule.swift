import Anthropic

/// 5-field POSIX cron schedule with computed runtime timestamps. Ported from
/// `beta_managed_agents_schedule.py`. The `type` field is always the literal `"cron"`.
public struct BetaManagedAgentsSchedule: Codable, Sendable, Equatable {
    public let expression: String
    public let timezone: String
    public let type: String
    public let lastRunAt: String?
    public let upcomingRunsAt: [String]?

    public init(
        expression: String,
        timezone: String,
        type: String = "cron",
        lastRunAt: String? = nil,
        upcomingRunsAt: [String]? = nil
    ) {
        self.expression = expression
        self.timezone = timezone
        self.type = type
        self.lastRunAt = lastRunAt
        self.upcomingRunsAt = upcomingRunsAt
    }
}

/// Request-side counterpart to `BetaManagedAgentsSchedule` -- literal wall-clock matching in the
/// configured timezone. Ported from `beta_managed_agents_schedule_params.py`.
public struct BetaManagedAgentsScheduleParams: Encodable, Sendable, Equatable {
    public var expression: String
    public var timezone: String
    public var type = "cron"

    public init(expression: String, timezone: String) {
        self.expression = expression
        self.timezone = timezone
    }
}
