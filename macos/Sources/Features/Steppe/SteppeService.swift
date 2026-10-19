import AppKit
import Combine
import Foundation

/// Owns the Herdr connection used by the Steppe chrome.
///
/// The store starts lazily when the first terminal window asks for the sidebar. The terminal
/// surface itself is unchanged: Herdr still runs inside it, and this object only mirrors Herdr's
/// workspaces, panes, and agents over the local socket.
@MainActor
final class SteppeService: ObservableObject {
    static let shared = SteppeService()

    @Published private(set) var store: HerdrStore
    @Published private(set) var session: HerdrSession
    @Published var isSidebarVisible: Bool {
        didSet {
            UserDefaults.standard.set(isSidebarVisible, forKey: Self.sidebarDefaultsKey)
        }
    }

    private static let sidebarDefaultsKey = "SteppeSidebarVisible"
    private let notifications = SteppeNotifications.shared
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        let session = HerdrSession.discover()
        self.session = session
        self.store = HerdrStore(session: session)

        if UserDefaults.standard.object(forKey: Self.sidebarDefaultsKey) == nil {
            self.isSidebarVisible = true
        } else {
            self.isSidebarVisible = UserDefaults.standard.bool(forKey: Self.sidebarDefaultsKey)
        }

        bind(store)
        observeSystemEvents()
        store.start()
    }

    // MARK: - Sessions

    var availableSessions: [HerdrSession] {
        var sessions: [HerdrSession] = []

        if session.exists || session.name == "default" {
            sessions.append(session)
        }

        for candidate in HerdrSession.availableSessions()
        where !sessions.contains(where: { $0.socketPath == candidate.socketPath }) {
            sessions.append(candidate)
        }

        return sessions
    }

    func selectSession(_ session: HerdrSession) {
        guard session.socketPath != self.session.socketPath else { return }

        store.stop()
        cancellables.removeAll()
        notifications.reset()

        self.session = session
        self.store = HerdrStore(session: session)

        bind(store)
        observeSystemEvents()
        store.start()
    }

    // MARK: - Chrome

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let paneId = userInfo[SteppeNotifications.paneIDKey] as? String else { return }

        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        }

        Task { [store] in
            await store.focus(agent: paneId)
        }
    }

    // MARK: - Bindings

    private func observeSystemEvents() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.store.refresh()
                }
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.store.refresh()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .ghosttyConfigDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self,
                      let config = notification.userInfo?[
                        Notification.Name.GhosttyConfigChangeKey
                      ] as? Ghostty.Config else {
                    return
                }

                let visible = config.steppeSidebar && self.isSidebarVisible
                for window in NSApp.windows {
                    (window.contentView as? TerminalViewContainer)?
                        .setSidebarVisible(visible)
                }
            }
            .store(in: &cancellables)
    }

    private func bind(_ store: HerdrStore) {
        notifications.start(store: store)

        store.$snapshot
            .combineLatest(store.$listedAgents)
            .receive(on: RunLoop.main)
            .map { snapshot, listed -> Int in
                var blocked: Set<String> = []

                for agent in snapshot?.agents ?? [] where agent.agentStatus == .blocked {
                    blocked.insert(agent.paneId)
                }
                for agent in listed where agent.agentStatus == .blocked {
                    blocked.insert(agent.paneId)
                }

                return blocked.count
            }
            .removeDuplicates()
            .sink { count in
                NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
            }
            .store(in: &cancellables)
    }
}
