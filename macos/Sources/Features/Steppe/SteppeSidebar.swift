import SwiftUI

private enum SteppeSidebarSelection: Hashable {
    case agent(String)
    case workspace(String)
}

/// Compact native chrome for a Herdr session. This is intentionally a list, not a second
/// terminal: clicks focus the corresponding Herdr pane, and the TUI inside the surface remains
/// the place where panes are drawn.
struct SteppeSidebarView: View {
    @ObservedObject var store: HerdrStore

    @State private var selection: SteppeSidebarSelection?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .background(.ultraThinMaterial)
        .onChange(of: selection) { newValue in
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

    private var header: some View {
        HStack(spacing: 8) {
            Text("Steppe")
                .font(.headline)

            Spacer()

            ConnectionDot(state: store.state)

            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Refresh Herdr")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        List(selection: $selection) {
            Section {
                if store.agents.isEmpty {
                    hint("No agents", "Start an agent in a Herdr pane.")
                } else {
                    ForEach(store.agents) { agent in
                        AgentRow(agent: agent)
                            .tag(SteppeSidebarSelection.agent(agent.paneId))
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
                    hint("No workspaces", "Herdr is not reporting a session.")
                } else {
                    ForEach(store.workspaces) { workspace in
                        WorkspaceRow(
                            workspace: workspace,
                            agentCount: store.agents(in: workspace.workspaceId).count
                        )
                        .tag(SteppeSidebarSelection.workspace(workspace.workspaceId))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(store.session.name)
                    .lineLimit(1)
                Spacer()
                if let lastRefresh = store.lastRefresh {
                    Text(lastRefresh, style: .time)
                        .monospacedDigit()
                }
            }

            if let detail = store.state.detail {
                Text(detail)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            } else {
                Text(store.state.label)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func hint(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

private struct AgentRow: View {
    let agent: AgentInfo

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            StatusDot(status: agent.agentStatus)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(agent.resolvedName)
                        .lineLimit(1)
                    if agent.focused {
                        Image(systemName: "scope")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(agent.statusLabel) · \(agent.paneId)")
                    .font(.caption)
                    .foregroundStyle(agent.agentStatus == .blocked ? .orange : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 1)
    }
}

private struct WorkspaceRow: View {
    let workspace: WorkspaceInfo
    let agentCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            StatusDot(status: workspace.agentStatus)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(workspace.label)
                        .lineLimit(1)
                    if workspace.focused {
                        Image(systemName: "scope")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 1)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let repo = workspace.worktree?.repoName { parts.append(repo) }
        parts.append("\(workspace.tabCount)t/\(workspace.paneCount)p")
        if agentCount > 0 { parts.append("\(agentCount) agents") }
        return parts.joined(separator: " · ")
    }
}

private struct StatusDot: View {
    let status: AgentStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay {
                if status == .blocked {
                    Circle().stroke(color.opacity(0.3), lineWidth: 3)
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
        case .unknown: .gray.opacity(0.4)
        }
    }
}

private struct ConnectionDot: View {
    let state: HerdrStore.ConnectionState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
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
