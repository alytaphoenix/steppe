import HerdrKit
import SwiftUI

enum SidebarSelection: Hashable {
    case agent(String)
    case workspace(String)
}

struct ContentView: View {
    @EnvironmentObject private var store: HerdrStore
    @State private var selection: SidebarSelection?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 380)
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                ConnectionPill(state: store.state)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh the Herdr snapshot")
            }
        }
        .onChange(of: selection) { _, newValue in
            guard let newValue else { return }
            Task {
                switch newValue {
                case .agent(let paneId):
                    await store.focus(agent: paneId)
                case .workspace(let workspaceId):
                    await store.focus(workspace: workspaceId)
                }
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                if store.agents.isEmpty {
                    SidebarHint(
                        title: "No agents detected",
                        detail: "Start an agent in a Herdr pane."
                    )
                } else {
                    ForEach(store.agents) { agent in
                        AgentRow(agent: agent)
                            .tag(SidebarSelection.agent(agent.paneId))
                    }
                }
            } header: {
                HStack {
                    Text("Agents")
                    Spacer()
                    if store.blockedCount > 0 {
                        Text("\(store.blockedCount) blocked")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Workspaces") {
                if store.workspaces.isEmpty {
                    SidebarHint(
                        title: "No workspaces",
                        detail: "Create one with Herdr or the CLI."
                    )
                } else {
                    ForEach(store.workspaces) { workspace in
                        WorkspaceRow(
                            workspace: workspace,
                            agentCount: store.agents(in: workspace.workspaceId).count
                        )
                        .tag(SidebarSelection.workspace(workspace.workspaceId))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SidebarFooter()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .agent(let paneId):
            if let agent = store.agents.first(where: { $0.paneId == paneId }) {
                AgentDetail(agent: agent)
            } else {
                ContentUnavailableView(
                    "Agent gone",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("The pane is no longer in the current snapshot.")
                )
            }

        case .workspace(let workspaceId):
            if let workspace = store.workspaces.first(where: { $0.workspaceId == workspaceId }) {
                WorkspaceDetail(
                    workspace: workspace,
                    tabs: store.tabs(in: workspaceId),
                    panes: store.panes(in: workspaceId),
                    agents: store.agents(in: workspaceId)
                )
            } else {
                ContentUnavailableView(
                    "Workspace gone",
                    systemImage: "square.stack.3d.up.slash",
                    description: Text("The workspace is no longer in the current snapshot.")
                )
            }

        case nil:
            Overview()
        }
    }
}

// MARK: - Sidebar rows

private struct AgentRow: View {
    let agent: AgentInfo

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            StatusDot(status: agent.agentStatus)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(agent.resolvedName)
                        .lineLimit(1)
                    if agent.focused {
                        Image(systemName: "scope")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 5) {
                    Text(agent.statusLabel)
                    Text("·")
                    Text(agent.workspaceId)
                    Text(agent.paneId)
                }
                .font(.caption)
                .foregroundStyle(agent.agentStatus == .blocked ? .orange : .secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct WorkspaceRow: View {
    let workspace: WorkspaceInfo
    let agentCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            StatusDot(status: workspace.agentStatus)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(workspace.label)
                        .lineLimit(1)
                    if workspace.focused {
                        Image(systemName: "scope")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 5) {
                    if let repo = workspace.worktree?.repoName {
                        Text(repo)
                        Text("·")
                    }
                    Text("\(workspace.tabCount) tabs")
                    Text("\(workspace.paneCount) panes")
                    if agentCount > 0 {
                        Text("· \(agentCount) agents")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SidebarHint: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.callout)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct SidebarFooter: View {
    @EnvironmentObject private var store: HerdrStore

    var body: some View {
        HStack(spacing: 6) {
            Text(store.session.name)
                .lineLimit(1)
            Spacer()
            if let lastRefresh = store.lastRefresh {
                Text(lastRefresh, style: .time)
                    .monospacedDigit()
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - Detail views

private struct Overview: View {
    @EnvironmentObject private var store: HerdrStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Steppe")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("The open range for your agent herd.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    MetricCard(
                        value: "\(store.workspaces.count)",
                        label: "workspaces",
                        symbol: "square.stack.3d.up"
                    )
                    MetricCard(
                        value: "\(store.totalPanes)",
                        label: "panes",
                        symbol: "rectangle.split.3x1"
                    )
                    MetricCard(
                        value: "\(store.agents.count)",
                        label: "agents",
                        symbol: "person.2"
                    )
                    MetricCard(
                        value: "\(store.blockedCount)",
                        label: "blocked",
                        symbol: "hand.raised",
                        tint: store.blockedCount > 0 ? .orange : .secondary
                    )
                }

                GroupBox("Connection") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Socket", value: store.session.socketPath)
                        LabeledContent("Session", value: store.session.name)
                        LabeledContent("Server", value: store.snapshot.map { "Herdr \($0.version) · protocol \($0.protocolVersion)" } ?? "—")
                        LabeledContent("State", value: store.state.label)

                        if let detail = store.state.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(6)
                }

                GroupBox("This is the M0 cockpit spike") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Herdr stays the runtime. This prototype reads its snapshot and events over the local socket; the terminal surface still belongs to Ghostty.")
                        Text("Next: fold this sidebar into a pinned Ghostty fork, add focus/create/split actions, then native notifications and the dock badge.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    .padding(6)
                }
            }
            .padding(32)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }
}

private struct AgentDetail: View {
    let agent: AgentInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center, spacing: 12) {
                    StatusDot(status: agent.agentStatus)
                        .scaleEffect(1.6)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(agent.resolvedName)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                        Text(agent.statusLabel)
                            .foregroundStyle(agent.agentStatus == .blocked ? .orange : .secondary)
                    }
                }

                GroupBox("Agent") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Status", value: agent.agentStatus.rawValue)
                        LabeledContent("Pane", value: agent.paneId)
                        LabeledContent("Terminal", value: agent.terminalId)
                        LabeledContent("Workspace", value: agent.workspaceId)
                        LabeledContent("Tab", value: agent.tabId)
                        if let cwd = agent.foregroundCwd ?? agent.cwd {
                            LabeledContent("CWD", value: cwd)
                        }
                        if let title = agent.title ?? agent.terminalTitle {
                            LabeledContent("Title", value: title)
                        }
                        LabeledContent("Focused", value: agent.focused ? "yes" : "no")
                    }
                    .padding(6)
                }

                if let tokens = agent.tokens, !tokens.isEmpty {
                    GroupBox("Metadata") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(tokens.keys.sorted(), id: \.self) { key in
                                LabeledContent(key, value: tokens[key] ?? "")
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

private struct WorkspaceDetail: View {
    let workspace: WorkspaceInfo
    let tabs: [TabInfo]
    let panes: [PaneInfo]
    let agents: [AgentInfo]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center, spacing: 12) {
                    StatusDot(status: workspace.agentStatus)
                        .scaleEffect(1.6)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workspace.label)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                        Text(workspace.worktree?.checkoutPath ?? workspace.workspaceId)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                GroupBox("Tabs") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(tabs) { tab in
                            HStack(spacing: 8) {
                                StatusDot(status: tab.agentStatus)
                                Text(tab.label)
                                Spacer()
                                Text(tab.tabId)
                                    .foregroundStyle(.secondary)
                                Text("\(tab.paneCount) panes")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(6)
                }

                GroupBox("Panes") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(panes) { pane in
                            HStack(spacing: 8) {
                                StatusDot(status: pane.agentStatus)
                                Text(pane.label ?? pane.title ?? pane.paneId)
                                    .lineLimit(1)
                                Spacer()
                                Text(pane.paneId)
                                    .foregroundStyle(.secondary)
                                if let agent = pane.displayAgent ?? pane.agent {
                                    Text(agent)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(6)
                }

                if !agents.isEmpty {
                    GroupBox("Agents") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(agents) { agent in
                                HStack(spacing: 8) {
                                    StatusDot(status: agent.agentStatus)
                                    Text(agent.resolvedName)
                                    Spacer()
                                    Text(agent.statusLabel)
                                        .foregroundStyle(agent.agentStatus == .blocked ? .orange : .secondary)
                                }
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

// MARK: - Small views

private struct StatusDot: View {
    let status: AgentStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay {
                if status == .blocked {
                    Circle()
                        .stroke(color.opacity(0.35), lineWidth: 4)
                }
            }
            .accessibilityLabel(status.label)
    }

    private var color: Color {
        switch status {
        case .blocked: .orange
        case .done: .green
        case .working: .blue
        case .idle: .secondary
        case .unknown: .gray.opacity(0.45)
        }
    }
}

private struct ConnectionPill: View {
    let state: HerdrStore.ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text("Herdr \(state.label)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .help(state.detail ?? "Herdr \(state.label)")
    }

    private var color: Color {
        switch state {
        case .connected: .green
        case .connecting: .yellow
        case .disconnected: .orange
        case .idle: .gray
        }
    }
}

private struct MetricCard: View {
    let value: String
    let label: String
    let symbol: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
