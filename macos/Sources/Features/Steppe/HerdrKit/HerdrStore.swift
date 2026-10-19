import Combine
import Foundation

@MainActor
public final class HerdrStore: ObservableObject {
    public enum ConnectionState: Equatable, Sendable {
        case idle
        case connecting
        case connected
        case disconnected(String)

        public var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }

        public var label: String {
            switch self {
            case .idle: "idle"
            case .connecting: "connecting"
            case .connected: "connected"
            case .disconnected: "disconnected"
            }
        }

        public var detail: String? {
            if case .disconnected(let message) = self { return message }
            return nil
        }
    }

    @Published public private(set) var snapshot: SessionSnapshot?
    @Published public private(set) var listedAgents: [AgentInfo] = []
    @Published public private(set) var state: ConnectionState = .idle
    @Published public private(set) var lastRefresh: Date?
    @Published public private(set) var eventCount: Int = 0
    @Published public private(set) var actionError: String?
    @Published public private(set) var lastStatusChange: AgentStatusChangedEvent?

    public let client: HerdrClient
    public let session: HerdrSession

    /// Called on the main actor whenever Herdr reports a semantic agent status change.
    public var onAgentStatusChange: ((AgentStatusChangedEvent) -> Void)?

    private var eventTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var activeSubscriptions: [HerdrSubscription] = []
    private var started = false

    public init(session: HerdrSession) {
        self.session = session
        self.client = HerdrClient(socketPath: session.socketPath)
    }

    deinit {
        eventTask?.cancel()
        pollTask?.cancel()
        refreshTask?.cancel()
    }

    // MARK: - Lifecycle

    public func start() {
        guard !started else { return }
        started = true
        state = .connecting
        activeSubscriptions = HerdrSubscriptions.lifecycle.map {
            HerdrSubscription(type: $0)
        }

        eventTask = Task { [weak self] in
            await self?.runEventLoop()
        }

        pollTask = Task { [weak self] in
            await self?.runPollLoop()
        }
    }

    public func stop() {
        started = false
        eventTask?.cancel()
        pollTask?.cancel()
        refreshTask?.cancel()
        eventTask = nil
        pollTask = nil
        refreshTask = nil
        activeSubscriptions = []
        state = .idle
    }

    // MARK: - Reads

    public func refresh() async {
        await refresh(restartEvents: true)
    }

    private func refresh(restartEvents: Bool) async {
        do {
            async let snapshotRequest = client.snapshot()
            async let agentsRequest = client.agents()

            let snapshot = try await snapshotRequest
            let agents = (try? await agentsRequest) ?? []

            if self.snapshot != snapshot {
                self.snapshot = snapshot
            }
            if self.listedAgents != agents {
                self.listedAgents = agents
            }

            self.state = .connected
            self.lastRefresh = Date()

            if restartEvents {
                restartEventsIfNeeded()
            } else {
                activeSubscriptions = desiredSubscriptions()
            }
        } catch {
            self.state = .disconnected(error.localizedDescription)
        }
    }

    private func runPollLoop() async {
        while !Task.isCancelled {
            await refresh()

            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
        }
    }

    private func runEventLoop() async {
        var backoffMilliseconds = 500

        while !Task.isCancelled {
            let subscriptions = activeSubscriptions.isEmpty
                ? HerdrSubscriptions.lifecycle.map { HerdrSubscription(type: $0) }
                : activeSubscriptions

            do {
                for try await event in client.events(subscriptions: subscriptions) {
                    eventCount += 1
                    handle(event)
                    scheduleRefresh()
                }

                if Task.isCancelled { return }
                state = .disconnected("event stream ended")
            } catch {
                if Task.isCancelled { return }

                let lost = (error as? HerdrError)?.code == "events_lost"
                state = .disconnected(error.localizedDescription)
                if lost {
                    backoffMilliseconds = 100
                }
            }

            do {
                try await Task.sleep(for: .milliseconds(backoffMilliseconds))
            } catch {
                return
            }

            if (try? await client.ping()) == nil {
                backoffMilliseconds = min(backoffMilliseconds * 2, 10_000)
            } else {
                backoffMilliseconds = 500
            }

            // Do not cancel the task we are running in. Refresh the authoritative state and
            // update the subscription list; the next loop iteration picks it up.
            await refresh(restartEvents: false)
        }
    }

    private func handle(_ event: HerdrEvent) {
        guard event.event == "pane.agent_status_changed"
            || event.event == "pane_agent_status_changed"
        else {
            return
        }

        guard let change = event.decodeData(AgentStatusChangedEvent.self) else {
            return
        }

        lastStatusChange = change
        onAgentStatusChange?(change)
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(80))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    // MARK: - Subscriptions

    private func desiredSubscriptions() -> [HerdrSubscription] {
        guard let snapshot else {
            return HerdrSubscriptions.lifecycle.map { HerdrSubscription(type: $0) }
        }
        return HerdrSubscriptions.forSnapshot(snapshot)
    }

    private func restartEventsIfNeeded() {
        let desired = desiredSubscriptions()
        guard desired != activeSubscriptions else { return }

        activeSubscriptions = desired
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            await self?.runEventLoop()
        }
    }

    // MARK: - Actions

    public func focus(workspace workspaceId: String) async {
        await perform {
            try await self.client.focusWorkspace(workspaceId)
        }
    }

    public func focus(tab tabId: String) async {
        await perform {
            try await self.client.focusTab(tabId)
        }
    }

    public func focus(agent target: String) async {
        await perform {
            try await self.client.focusAgent(target)
        }
    }

    public func focus(pane paneId: String) async {
        await perform {
            try await self.client.focusPane(paneId)
        }
    }

    /// Focus the first agent that needs attention, preferring one that is not already focused.
    public func focusNextAttention() async {
        let candidates = agents.filter { $0.agentStatus.isAttention }
        guard let next = candidates.first(where: { !$0.focused }) ?? candidates.first else {
            return
        }
        await focus(agent: next.paneId)
    }

    public func newWorkspace() async {
        await perform {
            _ = try await self.client.createWorkspace(focus: true)
        }
    }

    public func newTab() async {
        let workspaceId = snapshot?.focusedWorkspaceId ?? workspaces.first?.workspaceId
        await perform {
            _ = try await self.client.createTab(workspaceId: workspaceId, focus: true)
        }
    }

    public func splitFocusedPane(direction: SplitDirection) async {
        let paneId = snapshot?.focusedPaneId
        await perform {
            _ = try await self.client.splitPane(paneId: paneId, direction: direction, focus: true)
        }
    }

    private func perform(_ action: @escaping @MainActor () async throws -> Void) async {
        do {
            try await action()
            actionError = nil
            scheduleRefresh()
        } catch {
            actionError = error.localizedDescription
        }
    }

    // MARK: - Derived state

    public var workspaces: [WorkspaceInfo] {
        (snapshot?.workspaces ?? []).sorted { $0.number < $1.number }
    }

    public var agents: [AgentInfo] {
        var merged: [String: AgentInfo] = [:]
        for agent in snapshot?.agents ?? [] {
            merged[agent.paneId] = agent
        }
        for agent in listedAgents {
            merged[agent.paneId] = agent
        }
        for pane in snapshot?.panes ?? [] where pane.agent != nil || pane.agentStatus != .unknown {
            if merged[pane.paneId] == nil {
                merged[pane.paneId] = AgentInfo(pane: pane)
            }
        }

        return merged.values.sorted { lhs, rhs in
            let leftRank = rank(lhs.agentStatus)
            let rightRank = rank(rhs.agentStatus)
            if leftRank != rightRank { return leftRank < rightRank }
            return lhs.paneId.localizedStandardCompare(rhs.paneId) == .orderedAscending
        }
    }

    public var attentionAgents: [AgentInfo] {
        agents.filter { $0.agentStatus.isAttention }
    }

    public var blockedCount: Int {
        agents.filter { $0.agentStatus == .blocked }.count
    }

    public var totalPanes: Int {
        snapshot?.panes.count ?? 0
    }

    public func tabs(in workspaceId: String) -> [TabInfo] {
        snapshot?.tabs(in: workspaceId) ?? []
    }

    public func panes(in workspaceId: String) -> [PaneInfo] {
        snapshot?.panes(in: workspaceId) ?? []
    }

    public func agents(in workspaceId: String) -> [AgentInfo] {
        snapshot?.agents(in: workspaceId) ?? []
    }

    public func pane(_ paneId: String) -> PaneInfo? {
        snapshot?.panes.first { $0.paneId == paneId }
    }

    private func rank(_ status: AgentStatus) -> Int {
        switch status {
        case .blocked: 0
        case .done: 1
        case .working: 2
        case .idle: 3
        case .unknown: 4
        }
    }
}
