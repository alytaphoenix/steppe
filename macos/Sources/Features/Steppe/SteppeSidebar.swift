import AppKit
import SwiftUI

private enum SteppeSidebarSelection: Hashable {
    case agent(String)
    case workspace(String)
}

/// Compact native chrome for a Herdr session. This is intentionally a list, not a second
/// terminal: clicks focus the corresponding Herdr pane, and the TUI inside the surface remains
/// the place where panes are drawn.
struct SteppeSidebarView: View {
    @ObservedObject var service: SteppeService

    var body: some View {
        SteppeSidebarContent(service: service)
            .id(service.session.socketPath)
    }
}

private struct SteppeSidebarContent: View {
    @ObservedObject var service: SteppeService
    @ObservedObject private var store: HerdrStore

    @State private var selection: SteppeSidebarSelection?

    init(service: SteppeService) {
        self.service = service
        self._store = ObservedObject(wrappedValue: service.store)
    }

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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Steppe")
                    .font(.headline)

                Spacer()

                ConnectionDot(state: store.state)
            }

            HStack(spacing: 6) {
                sessionMenu

                Spacer()

                openHerdrButton
                actionsMenu
                refreshButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var sessionMenu: some View {
        Menu {
            ForEach(service.availableSessions, id: \.socketPath) { session in
                Button {
                    service.selectSession(session)
                } label: {
                    if session.socketPath == service.session.socketPath {
                        Label(session.name, systemImage: "checkmark")
                    } else {
                        Text(session.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "server.rack")
                Text(service.session.name)
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Herdr session")
    }

    private var openHerdrButton: some View {
        Button {
            (NSApp.delegate as? AppDelegate)?.openHerdr(nil)
        } label: {
            Image(systemName: "play.rectangle")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .help("Open Herdr in a new tab")
    }

    private var actionsMenu: some View {
        Menu {
            Button("New Workspace") {
                Task { await store.newWorkspace() }
            }
            Button("New Tab") {
                Task { await store.newTab() }
            }

            Divider()

            Button("Split Right") {
                Task { await store.splitFocusedPane(direction: .right) }
            }
            Button("Split Down") {
                Task { await store.splitFocusedPane(direction: .down) }
            }

            Divider()

            Button("Focus Next Attention") {
                Task { await store.focusNextAttention() }
            }
            .disabled(store.attentionAgents.isEmpty)
        } label: {
            Image(systemName: "plus")
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Herdr actions")
    }

    private var refreshButton: some View {
        Button {
            Task { await store.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .help("Refresh Herdr")
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
                            .help("\(agent.workspaceId) · \(agent.tabId) · \(agent.paneId)")
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
                        .help(workspace.worktree?.checkoutPath ?? workspace.workspaceId)
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
                Text("\(store.workspaces.count) spaces · \(store.totalPanes) panes")
                    .lineLimit(1)
                Spacer()
                if let lastRefresh = store.lastRefresh {
                    Text(lastRefresh, style: .time)
                        .monospacedDigit()
                }
            }

            if let actionError = store.actionError {
                Text(actionError)
                    .lineLimit(2)
                    .foregroundStyle(.orange)
            } else if let detail = store.state.detail {
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
        .accessibilityLabel("\(agent.resolvedName), \(agent.statusLabel)")
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
        .accessibilityLabel("\(workspace.label), \(subtitle)")
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
            .accessibilityLabel("Herdr \(state.label)")
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
