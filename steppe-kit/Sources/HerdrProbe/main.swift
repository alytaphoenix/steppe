import Foundation
import HerdrKit

// Keep probe output visible when it is piped to another process.
setvbuf(stdout, nil, _IONBF, 0)

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "snapshot"
let session = HerdrSession.discover()
let client = HerdrClient(socketPath: session.socketPath)

func printConnection() {
    print("socket:  \(session.socketPath)")
    print("session: \(session.name)")
    print("exists:  \(session.exists ? "yes" : "no")")
}

func printSnapshot(_ snapshot: SessionSnapshot) {
    print("herdr \(snapshot.version) (protocol \(snapshot.protocolVersion))")
    printConnection()
    print("")

    print("workspaces: \(snapshot.workspaces.count)   tabs: \(snapshot.tabs.count)   panes: \(snapshot.panes.count)   agents: \(snapshot.agents.count)")
    print("")

    for workspace in snapshot.workspaces.sorted(by: { $0.number < $1.number }) {
        let marker = workspace.focused ? "*" : " "
        let worktree = workspace.worktree?.repoName.map { " up:\($0)" } ?? ""
        print("\(marker) \(workspace.workspaceId)  \(workspace.label)  [\(workspace.agentStatus.rawValue)]  \(workspace.tabCount)t/\(workspace.paneCount)p\(worktree)")

        for tab in snapshot.tabs(in: workspace.workspaceId) {
            let tabMarker = tab.focused ? "*" : " "
            print("    \(tabMarker) \(tab.tabId)  \(tab.label)  [\(tab.agentStatus.rawValue)]  \(tab.paneCount)p")
        }

        for pane in snapshot.panes(in: workspace.workspaceId) {
            let paneMarker = pane.focused ? "*" : " "
            let label = pane.label ?? pane.title ?? pane.cwd ?? ""
            print("        \(paneMarker) \(pane.paneId)  [\(pane.agentStatus.rawValue)]  \(label)")
        }
    }

    if !snapshot.agents.isEmpty {
        print("")
        print("agent detail:")
        for agent in snapshot.agents {
            print("  \(agent.paneId)  \(agent.resolvedName)  [\(agent.statusLabel)]  \(agent.workspaceId)/\(agent.tabId)")
        }
    }
}

func prettyJSON<T: Encodable>(_ value: T) throws -> String {
    let data = try JSONEncoder.herdrPretty.encode(value)
    return String(data: data, encoding: .utf8) ?? "<encoding error>"
}

switch command {
case "snapshot":
    do {
        let snapshot = try await client.snapshot()
        if arguments.contains("--json") {
            print(try prettyJSON(snapshot))
        } else {
            printSnapshot(snapshot)
        }
    } catch {
        printConnection()
        fputs("\nerror: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "watch":
    let snapshot: SessionSnapshot
    do {
        snapshot = try await client.snapshot()
        printSnapshot(snapshot)
    } catch {
        printConnection()
        fputs("\nerror: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

    print("\nwatching for events (ctrl-c to stop)...\n")
    do {
        for try await event in client.events(subscriptions: HerdrSubscriptions.lifecycle) {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            print("\(timestamp)  \(event.event)")
        }
    } catch {
        fputs("event stream error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "ping":
    do {
        let pong = try await client.ping()
        print("pong: herdr \(pong.version), protocol \(pong.protocolVersion)")
    } catch {
        printConnection()
        fputs("\nerror: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "refresh":
    do {
        async let snapshotRequest = client.snapshot()
        async let agentsRequest = client.agents()
        let snapshot = try await snapshotRequest
        let agents = try await agentsRequest
        print("snapshot: \(snapshot.workspaces.count) workspaces, \(snapshot.panes.count) panes")
        print("agents: \(agents.count)")
    } catch {
        fputs("error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "store":
    let seconds = Double(arguments.dropFirst().first ?? "3") ?? 3
    let summary = await Task { @MainActor in
        let store = HerdrStore(session: session)
        var changes: [String] = []
        store.onAgentStatusChange = { change in
            changes.append("\(change.paneId):\(change.agentStatus.rawValue)")
        }
        store.start()
        try? await Task.sleep(for: .seconds(seconds))
        let last = store.lastStatusChange.map { "\($0.paneId):\($0.agentStatus.rawValue)" } ?? "none"
        return "state=\(store.state.label) workspaces=\(store.workspaces.count) panes=\(store.totalPanes) agents=\(store.agents.count) events=\(store.eventCount) last=\(last) changes=\(changes.joined(separator: ","))"
    }.value
    print(summary)

case "exercise":
    do {
        let workspace = try await client.createWorkspace(label: "steppe-exercise", focus: true)
        print("workspace: \(workspace.workspace.workspaceId) \(workspace.workspace.label)")

        let tab = try await client.createTab(
            workspaceId: workspace.workspace.workspaceId,
            label: "exercise",
            focus: true
        )
        print("tab: \(tab.tab.tabId) \(tab.tab.label)")

        let pane = try await client.splitPane(
            paneId: tab.rootPane.paneId,
            direction: .right,
            focus: true
        )
        print("split: \(pane.pane.paneId)")
    } catch {
        fputs("error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "focus":
    guard arguments.count >= 2 else {
        fputs("usage: herdr-probe focus <pane_id>\n", stderr)
        exit(2)
    }
    do {
        try await client.focusPane(arguments[1])
        print("focused \(arguments[1])")
    } catch {
        fputs("error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "sessions":
    let sessions = HerdrSession.availableSessions()
    if sessions.isEmpty {
        print("no named Herdr sessions found")
    } else {
        for session in sessions {
            print("\(session.name)  \(session.socketPath)")
        }
    }

case "help", "--help", "-h":
    print("""
    usage: herdr-probe <command>

    commands:
      snapshot [--json]   Print the live Herdr session
      watch               Print lifecycle events as they arrive
      ping                Check the server version and protocol
      refresh             Fetch snapshot and agent list concurrently
      store [seconds]     Start HerdrStore headlessly and print status changes
      exercise            Create a workspace, tab, and split through the socket
      focus <pane_id>     Focus a pane through Herdr
      sessions            List named sessions with sockets
    """)

default:
    fputs("unknown command: \(command)\n", stderr)
    fputs("run `herdr-probe help` for usage\n", stderr)
    exit(2)
}
