import Foundation
import Anthropic

/// A `agent.tool_use`/`agent.custom_tool_use` event dispatched by `SessionToolRunner`. Ported from
/// the `DispatchedToolUseEvent` union local to `_beta_session_runner.py`.
public enum DispatchedToolUseEvent: Sendable, Equatable {
    case toolUse(BetaManagedAgentsAgentToolUseEvent)
    case customToolUse(BetaManagedAgentsAgentCustomToolUseEvent)

    public var id: String {
        switch self {
        case .toolUse(let event): return event.id
        case .customToolUse(let event): return event.id
        }
    }

    public var name: String {
        switch self {
        case .toolUse(let event): return event.name
        case .customToolUse(let event): return event.name
        }
    }

    public var input: [String: JSONValue] {
        switch self {
        case .toolUse(let event): return event.input
        case .customToolUse(let event): return event.input
        }
    }

    /// `agent.custom_tool_use` carries no server-evaluated permission at all -- custom tools are
    /// always dispatched to the client -- so this is always `nil` for `.customToolUse`.
    public var evaluatedPermission: BetaManagedAgentsAgentEvaluatedPermission? {
        switch self {
        case .toolUse(let event): return event.evaluatedPermission
        case .customToolUse: return nil
        }
    }
}

/// A resolved `allow`/`deny` confirmation verdict. Distinct from the wire-level
/// `BetaManagedAgentsUserToolConfirmationResult` (which has an `.unknown(String)` case for
/// forward-compatibility) because by the time a verdict reaches `DispatchedToolCall` it has already
/// been resolved fail-closed: an unrecognized wire value is treated as `.deny`, matching Python's
/// `Literal["allow", "deny"]` invariant on the same field.
public enum ToolConfirmationVerdict: Sendable, Equatable {
    case allow
    case deny
}

/// The event-send payload produced for one dispatched tool call. Ported from
/// `DispatchedToolResultParams` in `_beta_session_runner.py`.
public enum DispatchedToolResultParams: Sendable, Equatable {
    case toolResult(BetaManagedAgentsUserToolResultEventParams)
    case customToolResult(BetaManagedAgentsUserCustomToolResultEventParams)

    var asEventParams: BetaManagedAgentsEventParams {
        switch self {
        case .toolResult(let params): return .userToolResult(params)
        case .customToolResult(let params): return .userCustomToolResult(params)
        }
    }
}

/// One completed (or denied) tool dispatch, yielded by `SessionToolRunner.run()`. Ported from the
/// `DispatchedToolCall` dataclass in `_beta_session_runner.py`.
public struct DispatchedToolCall: Sendable, Equatable {
    public let event: DispatchedToolUseEvent
    /// `nil` when the call was denied before ever being executed.
    public let result: DispatchedToolResultParams?
    public let toolUseId: String
    public let name: String
    public let isError: Bool
    /// Whether `result` was successfully posted back to the session via `events.send`. `false` for a
    /// denial (nothing is posted -- the server already knows) or when posting the executed result
    /// failed.
    public let posted: Bool
    /// The confirmation verdict that unblocked this call, if the tool's `evaluatedPermission` was
    /// `.ask`. `nil` for an unconditionally-allowed or unconditionally-denied call.
    public let confirmation: ToolConfirmationVerdict?
}

/// Runs the client side of a Managed Agents session's `self_hosted`-environment tool loop: watches
/// `client.beta.sessions.events.stream`, dispatches every `agent.tool_use`/`agent.custom_tool_use`
/// event to a locally-registered `AnthropicTool`, and posts each result back via
/// `client.beta.sessions.events.send`. Ported from `_beta_session_runner.py`'s
/// `SessionToolRunner` (Slice 4 Milestone D per the governing plan).
///
/// An `actor` rather than a plain class: Python's runner keeps `_seen`/`_answered`/`_confirmations`/
/// `_awaiting_confirmation` as plain attributes mutated cooperatively by three concurrently-scheduled
/// coroutines (`_stream_loop`, `_dispatch_loop`, `_idle_watchdog`) under `anyio`'s single-threaded
/// event loop. Actor isolation reproduces that exact cooperative-mutual-exclusion guarantee directly,
/// with each Python coroutine becoming an actor-isolated `async` method spawned as a child task in a
/// `withThrowingTaskGroup`.
///
/// Two simplifications relative to Python, both intentional:
/// - No `_stop_watcher` task: `AsyncStream.finish()` (called from `stop()`) directly unblocks
///   `dispatchLoop`'s `for await`, which is the only thing Python's stop-watcher task existed to do.
/// - The idle clock's event-driven wake (Python's `_IdleClock` uses an `anyio.Event` to wake
///   `_idle_watchdog` the instant it's armed, held, or released) is replaced by simple polling
///   (`idlePollInterval`, 1 second). Exact continuation-based wake replication risks actor-isolation/
///   cancellation races for no real benefit -- sub-second wake precision is immaterial against a
///   default 60-second idle timeout. Every hold/release/arm/disarm/deferred-arm *semantic* is ported
///   exactly; only the wake mechanism differs.
///
/// Out of scope: Python's exit-time tool-cleanup hook (`close`/`__exit__`/`__aexit__`) -- Swift's
/// `AnthropicTool` has no equivalent lifecycle hook, mirroring `BetaToolRunner`'s stance that a tool
/// needing teardown manages its own resources.
///
/// Not `Sendable`-callable concurrently for multiple `run()`s -- like `BetaToolRunner`, one
/// `SessionToolRunner` drives one session's tool loop.
public actor SessionToolRunner {
    private struct WorkItem: Sendable {
        let event: DispatchedToolUseEvent
        let confirmation: ToolConfirmationVerdict?
    }

    private let events: BetaSessionEvents
    private let sessionId: String
    private let toolsByName: [String: AnyAnthropicTool]
    private let maxIdle: TimeInterval?
    private let betas: [String]
    private let baseOptions: RequestOptions

    private var seen: Set<String> = []
    private var answered: Set<String> = []
    private var confirmations: [String: ToolConfirmationVerdict] = [:]
    private var awaitingConfirmation: [String: DispatchedToolUseEvent] = [:]

    private var idleEndTurnAt: TimeInterval?
    private var idleHolds = 0
    private var idleArmDeferred = false

    private var stopped = false
    private let workStream: AsyncStream<WorkItem>
    private let workContinuation: AsyncStream<WorkItem>.Continuation
    private var outputContinuation: AsyncThrowingStream<DispatchedToolCall, Error>.Continuation?

    /// Reuses `HTTPTransport`'s own initial-delay/cap for exponential backoff, since Python's
    /// reconnect loop doesn't specify a distinct pair and this keeps every retry loop in the SDK
    /// consistent.
    private static let streamBackoffStart: TimeInterval = 0.5
    private static let streamBackoffCap: TimeInterval = 8.0
    private static let idlePollInterval: TimeInterval = 1.0
    private static let reconcilePageLimit = 1000

    public init(
        client: AnthropicClient,
        sessionId: String,
        tools: [AnyAnthropicTool],
        maxIdle: TimeInterval? = 60,
        environmentKey: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) {
        self.events = BetaSessionEvents(client: client)
        self.sessionId = sessionId
        self.toolsByName = Dictionary(tools.map { ($0.name, $0) }, uniquingKeysWith: { _, latest in latest })
        self.maxIdle = maxIdle
        self.betas = betas
        if let environmentKey {
            var headers = options.headers
            headers["authorization"] = "Bearer \(environmentKey)"
            headers["x-api-key"] = nil
            self.baseOptions = RequestOptions(headers: headers, maxRetries: options.maxRetries, timeout: options.timeout)
        } else {
            self.baseOptions = options
        }
        var continuation: AsyncStream<WorkItem>.Continuation!
        self.workStream = AsyncStream { continuation = $0 }
        self.workContinuation = continuation
    }

    /// Starts the tool loop and returns the stream of dispatched calls. Ends when the session
    /// terminates or is deleted, when a non-retryable transport error occurs, or when the consumer
    /// stops iterating (which gracefully winds the loop down via `stop()` rather than force-cancelling
    /// an in-flight tool execution).
    public func run() -> AsyncThrowingStream<DispatchedToolCall, Error> {
        AsyncThrowingStream { continuation in
            continuation.onTermination = { _ in
                Task { await self.stop() }
            }
            Task {
                await self.start(continuation: continuation)
            }
        }
    }

    private func start(continuation: AsyncThrowingStream<DispatchedToolCall, Error>.Continuation) async {
        outputContinuation = continuation
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await self.streamLoop() }
                group.addTask { await self.dispatchLoop() }
                if self.maxIdle != nil {
                    group.addTask { await self.idleWatchdog() }
                }
                try await group.waitForAll()
            }
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }

    private func stop() {
        guard !stopped else { return }
        stopped = true
        workContinuation.finish()
    }

    private func yield(_ call: DispatchedToolCall) {
        outputContinuation?.yield(call)
    }

    // MARK: - Stream loop

    /// Opens the SSE connection *before* reconciling on every (re)connect attempt, so an event
    /// landing in the list-then-attach gap is delivered live instead of lost -- `seen` dedups the
    /// resulting overlap between the reconciled history and the live stream.
    private func streamLoop() async throws {
        var backoff = Self.streamBackoffStart
        while !stopped {
            do {
                let stream = try await events.stream(sessionId: sessionId, betas: betas, options: baseOptions)
                await reconcile()
                for try await event in stream {
                    if stopped { return }
                    backoff = Self.streamBackoffStart
                    await handleStreamEvent(event)
                    if stopped { return }
                }
            } catch is CancellationError {
                return
            } catch let error as AnthropicError {
                if stopped { return }
                guard error.isRetryable else {
                    stop()
                    return
                }
            }
            if stopped { return }
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            backoff = min(backoff * 2, Self.streamBackoffCap)
        }
    }

    private func handleStreamEvent(_ event: BetaManagedAgentsStreamSessionEvents) async {
        noteIdleEvent(event)
        switch event {
        case .agentToolUse(let toolUse):
            guard !seen.contains(toolUse.id) else { return }
            seen.insert(toolUse.id)
            await route(.toolUse(toolUse))
        case .agentCustomToolUse(let toolUse):
            guard !seen.contains(toolUse.id) else { return }
            seen.insert(toolUse.id)
            await route(.customToolUse(toolUse))
        case .userToolResult(let result):
            answered.insert(result.toolUseId)
        case .userCustomToolResult(let result):
            answered.insert(result.customToolUseId)
        case .userToolConfirmation(let confirmation):
            await noteConfirmation(confirmation)
        case .sessionStatusTerminated, .sessionDeleted:
            stop()
        default:
            break
        }
    }

    private func noteConfirmation(_ event: BetaManagedAgentsUserToolConfirmationEvent) async {
        let verdict: ToolConfirmationVerdict = event.result == .allow ? .allow : .deny
        confirmations[event.toolUseId] = verdict
        guard let held = awaitingConfirmation[event.toolUseId] else { return }
        applyVerdict(held, verdict: verdict)
    }

    // MARK: - Reconcile

    /// Reads the session's entire event history (manually paginating, since `PageCursor` has no
    /// auto-iteration helper -- see its doc comment) and replays it through the same dedup/routing
    /// logic as the live stream, so a runner attaching to an already-in-progress session (or
    /// reconnecting after a drop) catches up on anything it missed.
    private func reconcile() async {
        var newlySeen: [String] = []
        var lastWasEndTurn = false
        let unanswered: [DispatchedToolUseEvent]

        do {
            var allEvents: [BetaManagedAgentsSessionEvent] = []
            var page = try await events.list(
                sessionId: sessionId, limit: Self.reconcilePageLimit, betas: betas, options: baseOptions
            )
            while true {
                allEvents.append(contentsOf: page.data)
                guard let next = page.nextPage else { break }
                page = try await events.list(
                    sessionId: sessionId, limit: Self.reconcilePageLimit, page: next, betas: betas,
                    options: baseOptions
                )
            }

            var pending: [DispatchedToolUseEvent] = []
            for sessionEvent in allEvents {
                switch sessionEvent {
                case .agentToolUse(let toolUse):
                    lastWasEndTurn = false
                    if !seen.contains(toolUse.id) {
                        seen.insert(toolUse.id)
                        newlySeen.append(toolUse.id)
                        pending.append(.toolUse(toolUse))
                    }
                case .agentCustomToolUse(let toolUse):
                    lastWasEndTurn = false
                    if !seen.contains(toolUse.id) {
                        seen.insert(toolUse.id)
                        newlySeen.append(toolUse.id)
                        pending.append(.customToolUse(toolUse))
                    }
                case .userToolResult(let result):
                    lastWasEndTurn = false
                    answered.insert(result.toolUseId)
                case .userCustomToolResult(let result):
                    lastWasEndTurn = false
                    answered.insert(result.customToolUseId)
                case .userToolConfirmation(let confirmation):
                    lastWasEndTurn = false
                    if !answered.contains(confirmation.toolUseId) {
                        confirmations[confirmation.toolUseId] = confirmation.result == .allow ? .allow : .deny
                    }
                case .sessionStatusIdle(let idle):
                    if case .endTurn = idle.stopReason {
                        lastWasEndTurn = true
                    } else {
                        lastWasEndTurn = false
                    }
                default:
                    lastWasEndTurn = false
                }
            }
            unanswered = pending.filter { !answered.contains($0.id) }
        } catch {
            // Roll back this incomplete batch's `seen` additions so the live stream (or the next
            // reconcile) can pick these tool-use events up again instead of silently dropping them.
            for id in newlySeen { seen.remove(id) }
            return
        }

        idleDisarm()
        for event in unanswered {
            await route(event)
        }
        // A held call's tool-use event and its confirmation can land in different pages, or the
        // confirmation can even predate the tool-use event during reconciliation -- apply any verdict
        // already known for a call that's still held.
        for id in Array(awaitingConfirmation.keys) {
            guard let event = awaitingConfirmation[id], let verdict = confirmations[id] else { continue }
            applyVerdict(event, verdict: verdict)
        }
        if lastWasEndTurn {
            idleArm()
        }
    }

    // MARK: - Routing and confirmation

    private func route(_ event: DispatchedToolUseEvent) async {
        if case .deny = event.evaluatedPermission {
            resolveDenied(event)
            return
        }
        guard let verdict = confirmations[event.id] else {
            switch event.evaluatedPermission {
            case nil, .allow:
                enqueueWork(event, confirmation: nil)
            default:
                // `.ask` or an unrecognized permission value -- fail closed and hold for an explicit
                // confirmation rather than dispatching.
                if awaitingConfirmation[event.id] == nil {
                    awaitingConfirmation[event.id] = event
                    idleHold()
                }
            }
            return
        }
        applyVerdict(event, verdict: verdict)
    }

    private func applyVerdict(_ event: DispatchedToolUseEvent, verdict: ToolConfirmationVerdict) {
        let wasHeld = awaitingConfirmation.removeValue(forKey: event.id) != nil
        switch verdict {
        case .allow:
            if !wasHeld { idleHold() }
            enqueueWork(event, confirmation: .allow)
        case .deny:
            if wasHeld { idleRelease() }
            resolveDenied(event)
        }
    }

    private func resolveDenied(_ event: DispatchedToolUseEvent) {
        answered.insert(event.id)
        yield(DispatchedToolCall(
            event: event, result: nil, toolUseId: event.id, name: event.name,
            isError: false, posted: false, confirmation: .deny
        ))
    }

    private func enqueueWork(_ event: DispatchedToolUseEvent, confirmation: ToolConfirmationVerdict?) {
        workContinuation.yield(WorkItem(event: event, confirmation: confirmation))
    }

    // MARK: - Dispatch loop

    private func dispatchLoop() async {
        for await item in workStream {
            defer {
                if item.confirmation == .allow { idleRelease() }
            }
            if !answered.contains(item.event.id) {
                await execute(item.event, confirmation: item.confirmation)
            }
        }
    }

    private func execute(_ event: DispatchedToolUseEvent, confirmation: ToolConfirmationVerdict?) async {
        let output: ToolOutput
        let isError: Bool
        if let tool = toolsByName[event.name] {
            let context = ToolRunContext(toolUseId: event.id, toolName: event.name)
            do {
                output = try await tool.run(.object(event.input), context: context)
                isError = false
            } catch let toolError as ToolError {
                output = toolError.content
                isError = true
            } catch {
                output = .text(String(describing: error))
                isError = true
            }
        } else {
            output = .text("Error: Tool '\(event.name)' not found")
            isError = true
        }

        let result = Self.buildResultEvent(for: event, output: output, isError: isError)
        let posted = await sendResult(result)
        answered.insert(event.id)
        yield(DispatchedToolCall(
            event: event, result: result, toolUseId: event.id, name: event.name,
            isError: isError, posted: posted, confirmation: confirmation
        ))
    }

    private func sendResult(_ result: DispatchedToolResultParams) async -> Bool {
        do {
            _ = try await events.send(
                sessionId: sessionId, events: [result.asEventParams], betas: betas, options: baseOptions
            )
            return true
        } catch {
            return false
        }
    }

    private static func buildResultEvent(
        for event: DispatchedToolUseEvent, output: ToolOutput, isError: Bool
    ) -> DispatchedToolResultParams {
        let content = bridgeContent(output)
        switch event {
        case .toolUse:
            return .toolResult(
                BetaManagedAgentsUserToolResultEventParams(toolUseId: event.id, content: content, isError: isError)
            )
        case .customToolUse:
            return .customToolResult(
                BetaManagedAgentsUserCustomToolResultEventParams(
                    customToolUseId: event.id, content: content, isError: isError
                )
            )
        }
    }

    // MARK: - Idle clock

    /// Ported from Python's `_IdleClock`. Invariant: "armed" means `idleEndTurnAt != nil`;
    /// "deferred-armed" means `idleEndTurnAt == nil && idleArmDeferred && idleHolds > 0`. A hold taken
    /// while armed converts the running countdown into a deferred one instead of just clearing it, so
    /// the deferred arm is re-applied (with a fresh timestamp) the moment the last hold releases.
    private func idleArm() {
        guard idleHolds == 0 else {
            idleArmDeferred = true
            return
        }
        idleEndTurnAt = now()
    }

    private func idleDisarm() {
        idleArmDeferred = false
        idleEndTurnAt = nil
    }

    private func idleHold() {
        idleHolds += 1
        if idleEndTurnAt != nil {
            idleEndTurnAt = nil
            idleArmDeferred = true
        }
    }

    private func idleRelease() {
        idleHolds -= 1
        if idleHolds == 0 && idleArmDeferred {
            idleArmDeferred = false
            idleArm()
        }
    }

    private func noteIdleEvent(_ event: BetaManagedAgentsStreamSessionEvents) {
        if case .sessionStatusIdle(let idle) = event, case .endTurn = idle.stopReason {
            idleArm()
        } else {
            idleDisarm()
        }
    }

    /// Polls rather than waking on an event -- see the type-level doc comment for why.
    private func idleWatchdog() async {
        guard let maxIdle else { return }
        while !stopped {
            if let armedAt = idleEndTurnAt {
                let remaining = maxIdle - (now() - armedAt)
                if remaining <= 0 {
                    stop()
                    return
                }
                try? await Task.sleep(nanoseconds: UInt64(min(remaining, Self.idlePollInterval) * 1_000_000_000))
            } else {
                try? await Task.sleep(nanoseconds: UInt64(Self.idlePollInterval * 1_000_000_000))
            }
        }
    }

    private func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}

/// Bridges a locally-executed tool's `ToolOutput` into the Sessions wire format. Ported from
/// `_to_session_content` in `_beta_session_runner.py`, standalone (not `SessionToolRunner`-isolated)
/// since it's pure content transformation with no actor state.
///
/// GA's `ToolResultContentBlockParam`/`DocumentSourceParam` are structurally richer than their
/// Sessions counterparts in two places that have no Sessions equivalent at all:
/// `.toolReference`/`.browserState` result blocks, and `DocumentSourceParam.content` (a document
/// sourced from inline content blocks rather than base64/text/url/file). Both are JSON-stringified
/// into a text block, mirroring Python's "anything else is JSON-stringified" fallback policy.
private func bridgeContent(_ output: ToolOutput) -> [BetaManagedAgentsToolResultContentParam] {
    switch output {
    case .text(let text):
        return [.text(BetaManagedAgentsTextBlockParam(text: text.isEmpty ? "(no output)" : text))]
    case .blocks(let blocks):
        guard !blocks.isEmpty else {
            return [.text(BetaManagedAgentsTextBlockParam(text: "(no output)"))]
        }
        return blocks.map(bridgeBlock)
    }
}

private func bridgeBlock(_ block: ToolResultContentBlockParam) -> BetaManagedAgentsToolResultContentParam {
    switch block {
    case .text(let text):
        return .text(BetaManagedAgentsTextBlockParam(text: text.text))
    case .image(let image):
        return .image(BetaManagedAgentsImageBlockParam(source: bridgeImageSource(image.source)))
    case .document(let document):
        return bridgeDocument(document)
    case .searchResult(let searchResult):
        return .searchResult(bridgeSearchResult(searchResult))
    case .toolReference, .browserState:
        return .text(BetaManagedAgentsTextBlockParam(text: jsonStringify(block)))
    }
}

private func bridgeImageSource(_ source: ImageSourceParam) -> BetaManagedAgentsImageSourceParam {
    switch source {
    case .base64(let base64):
        return .base64(
            BetaManagedAgentsBase64ImageSourceParam(data: base64.data, mediaType: base64.mediaType.rawValue)
        )
    case .url(let url):
        return .url(BetaManagedAgentsURLImageSourceParam(url: url.url))
    case .file(let file):
        return .file(BetaManagedAgentsFileImageSourceParam(fileId: file.fileId))
    }
}

private func bridgeDocument(_ document: DocumentBlockParam) -> BetaManagedAgentsToolResultContentParam {
    let source: BetaManagedAgentsDocumentSourceParam
    switch document.source {
    case .base64PDF(let pdf):
        source = .base64(BetaManagedAgentsBase64DocumentSourceParam(data: pdf.data, mediaType: "application/pdf"))
    case .plainText(let text):
        source = .plainText(BetaManagedAgentsPlainTextDocumentSourceParam(data: text.data))
    case .url(let url):
        source = .url(BetaManagedAgentsURLDocumentSourceParam(url: url.url))
    case .file(let file):
        source = .file(BetaManagedAgentsFileDocumentSourceParam(fileId: file.fileId))
    case .content:
        // No Sessions equivalent for a document sourced from inline content blocks.
        return .text(BetaManagedAgentsTextBlockParam(text: jsonStringify(document)))
    }
    return .document(
        BetaManagedAgentsDocumentBlockParam(source: source, context: document.context, title: document.title)
    )
}

private func bridgeSearchResult(_ searchResult: SearchResultBlockParam) -> BetaManagedAgentsSearchResultBlockParam {
    BetaManagedAgentsSearchResultBlockParam(
        citations: BetaManagedAgentsSearchResultCitationsParam(enabled: searchResult.citations?.enabled ?? false),
        content: searchResult.content.map { BetaManagedAgentsSearchResultContentParam(text: $0.text) },
        source: searchResult.source,
        title: searchResult.title
    )
}

/// `HTTPTransport.encoder` is `package`-scoped precisely so call sites like this (outside the
/// `Anthropic` module) can reuse it instead of standing up a second encoder.
private func jsonStringify<T: Encodable>(_ value: T) -> String {
    guard let data = try? HTTPTransport.encoder.encode(value), let string = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return string
}
