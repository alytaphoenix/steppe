import Foundation

public enum AgentStatus: String, Codable, Sendable, CaseIterable {
    case idle
    case working
    case blocked
    case done
    case unknown

    public var isAttention: Bool {
        self == .blocked || self == .done
    }

    public var label: String {
        switch self {
        case .idle: "idle"
        case .working: "working"
        case .blocked: "needs input"
        case .done: "done"
        case .unknown: "unknown"
        }
    }
}

public struct WorkspaceWorktreeInfo: Codable, Sendable, Equatable {
    public var checkoutPath: String?
    public var isLinkedWorktree: Bool?
    public var repoKey: String?
    public var repoName: String?
    public var repoRoot: String?
}

public struct WorkspaceInfo: Codable, Sendable, Equatable, Identifiable {
    public var workspaceId: String
    public var number: Int
    public var label: String
    public var focused: Bool
    public var paneCount: Int
    public var tabCount: Int
    public var activeTabId: String
    public var agentStatus: AgentStatus
    public var tokens: [String: String]?
    public var worktree: WorkspaceWorktreeInfo?

    public var id: String { workspaceId }
}

public struct TabInfo: Codable, Sendable, Equatable, Identifiable {
    public var tabId: String
    public var workspaceId: String
    public var number: Int
    public var label: String
    public var focused: Bool
    public var paneCount: Int
    public var agentStatus: AgentStatus

    public var id: String { tabId }
}

public struct PaneScrollInfo: Codable, Sendable, Equatable {
    public var offsetFromBottom: Int
    public var maxOffsetFromBottom: Int
    public var viewportRows: Int
}

public struct AgentSessionInfo: Codable, Sendable, Equatable {
    public var source: String
    public var agent: String
    public var kind: String
    public var value: String
}

public struct PaneInfo: Codable, Sendable, Equatable, Identifiable {
    public var paneId: String
    public var terminalId: String
    public var workspaceId: String
    public var tabId: String
    public var focused: Bool
    public var agentStatus: AgentStatus
    public var revision: Int
    public var label: String?
    public var cwd: String?
    public var foregroundCwd: String?
    public var agent: String?
    public var displayAgent: String?
    public var title: String?
    public var terminalTitle: String?
    public var terminalTitleStripped: String?
    public var agentSession: AgentSessionInfo?
    public var scroll: PaneScrollInfo?
    public var stateLabels: [String: String]?
    public var tokens: [String: String]?
    public var restoreError: String?

    public var id: String { paneId }
}

public struct AgentInfo: Codable, Sendable, Equatable, Identifiable {
    public var paneId: String
    public var terminalId: String
    public var workspaceId: String
    public var tabId: String
    public var focused: Bool
    public var agentStatus: AgentStatus
    public var revision: Int
    public var agent: String?
    public var name: String?
    public var displayAgent: String?
    public var title: String?
    public var terminalTitle: String?
    public var terminalTitleStripped: String?
    public var cwd: String?
    public var foregroundCwd: String?
    public var agentSession: AgentSessionInfo?
    public var stateLabels: [String: String]?
    public var tokens: [String: String]?
    public var interactiveReady: Bool?
    public var launchPending: Bool?
    public var completionSeq: Int?
    public var stateChangeSeq: Int?
    public var screenDetectionSkipped: Bool?

    public var id: String { paneId }

    /// The best human-readable name available, in preference order.
    public var resolvedName: String {
        if let displayAgent, !displayAgent.isEmpty { return displayAgent }
        if let name, !name.isEmpty { return name }
        if let agent, !agent.isEmpty { return agent }
        if let title, !title.isEmpty { return title }
        return "agent"
    }

    public var statusLabel: String {
        if let label = stateLabels?[agentStatus.rawValue], !label.isEmpty {
            return label
        }
        return agentStatus.label
    }
}

extension AgentInfo {
    /// Some server versions only expose reported agents on the pane record. Keep a single
    /// display path by projecting panes into the same shape.
    public init(pane: PaneInfo) {
        self.init(
            paneId: pane.paneId,
            terminalId: pane.terminalId,
            workspaceId: pane.workspaceId,
            tabId: pane.tabId,
            focused: pane.focused,
            agentStatus: pane.agentStatus,
            revision: pane.revision,
            agent: pane.agent,
            name: nil,
            displayAgent: pane.displayAgent,
            title: pane.title,
            terminalTitle: pane.terminalTitle,
            terminalTitleStripped: pane.terminalTitleStripped,
            cwd: pane.cwd,
            foregroundCwd: pane.foregroundCwd,
            agentSession: pane.agentSession,
            stateLabels: pane.stateLabels,
            tokens: pane.tokens,
            interactiveReady: nil,
            launchPending: nil,
            completionSeq: nil,
            stateChangeSeq: nil,
            screenDetectionSkipped: nil
        )
    }
}

public struct PaneLayoutRect: Codable, Sendable, Equatable {    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
}

public struct PaneLayoutPane: Codable, Sendable, Equatable {
    public var paneId: String
    public var focused: Bool
    public var rect: PaneLayoutRect
}

public struct PaneLayoutSnapshot: Codable, Sendable, Equatable, Identifiable {
    public var workspaceId: String
    public var tabId: String
    public var focusedPaneId: String
    public var zoomed: Bool
    public var area: PaneLayoutRect
    public var panes: [PaneLayoutPane]
    public var splits: [JSONValue]

    public var id: String { tabId }
}

public struct SessionSnapshot: Codable, Sendable, Equatable {
    public var version: String
    public var protocolVersion: Int
    public var workspaces: [WorkspaceInfo]
    public var tabs: [TabInfo]
    public var panes: [PaneInfo]
    public var layouts: [PaneLayoutSnapshot]
    public var agents: [AgentInfo]
    public var focusedWorkspaceId: String?
    public var focusedTabId: String?
    public var focusedPaneId: String?

    enum CodingKeys: String, CodingKey {
        case version
        case protocolVersion = "protocol"
        case workspaces
        case tabs
        case panes
        case layouts
        case agents
        case focusedWorkspaceId
        case focusedTabId
        case focusedPaneId
    }

    public var blockedAgents: [AgentInfo] {
        agents.filter { $0.agentStatus == .blocked }
    }

    public var attentionAgents: [AgentInfo] {
        agents.filter { $0.agentStatus == .blocked || $0.agentStatus == .done }
    }

    public func tabs(in workspaceId: String) -> [TabInfo] {
        tabs.filter { $0.workspaceId == workspaceId }.sorted { $0.number < $1.number }
    }

    public func panes(in workspaceId: String) -> [PaneInfo] {
        panes.filter { $0.workspaceId == workspaceId }
    }

    public func agents(in workspaceId: String) -> [AgentInfo] {
        agents.filter { $0.workspaceId == workspaceId }
    }
}

public enum HerdrSubscriptions {
    /// Lifecycle events that invalidate a cached snapshot. Status changes for individual panes
    /// are not included because Herdr requires a `pane_id` for those subscriptions; the store
    /// polls as a safety net and will move to per-pane subscriptions once the UI needs sub-second
    /// status latency.
    public static let lifecycle: [String] = [
        "workspace.created",
        "workspace.updated",
        "workspace.metadata_updated",
        "workspace.renamed",
        "workspace.moved",
        "workspace.reordered",
        "workspace.closed",
        "workspace.focused",
        "worktree.created",
        "worktree.opened",
        "worktree.removed",
        "tab.created",
        "tab.closed",
        "tab.focused",
        "tab.renamed",
        "tab.moved",
        "pane.created",
        "pane.closed",
        "pane.updated",
        "pane.focused",
        "pane.moved",
        "pane.exited",
        "pane.agent_detected",
        "layout.updated",
    ]
}

public struct HerdrEvent: Codable, Sendable, Equatable {
    public var event: String
    public var data: JSONValue?

    public init(event: String, data: JSONValue? = nil) {
        self.event = event
        self.data = data
    }
}

public struct HerdrError: Codable, Error, Sendable, Equatable, LocalizedError {
    public var code: String
    public var message: String

    public var errorDescription: String? {
        "\(code): \(message)"
    }
}

public struct ResponseEnvelope<Result: Codable & Sendable>: Codable, Sendable {
    public var id: String?
    public var result: Result?
    public var error: HerdrError?
}

public struct SnapshotResult: Codable, Sendable {
    public var type: String
    public var snapshot: SessionSnapshot
}

public struct AckResult: Codable, Sendable {
    public var type: String
}

public struct PongResult: Codable, Sendable {
    public var type: String
    public var version: String
    public var protocolVersion: Int

    enum CodingKeys: String, CodingKey {
        case type
        case version
        case protocolVersion = "protocol"
    }
}

public struct AgentListResult: Codable, Sendable {
    public var type: String
    public var agents: [AgentInfo]
}

extension JSONDecoder {
    /// Herdr emits snake_case keys. Unknown fields are ignored by design.
    public static var herdr: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

extension JSONEncoder {
    /// Used when printing protocol values for humans.
    public static var herdrPretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
