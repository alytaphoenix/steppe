import Foundation
import OSLog
import UserNotifications

/// Posts native notifications when a Herdr agent transitions into a state that needs attention.
///
/// Herdr's own toast delivery defaults to `off`, so there is no double-notification problem. The
/// notification payload carries the public pane id; `AppDelegate` routes clicks back to
/// `SteppeService.handleNotification`.
@MainActor
final class SteppeNotifications {
    static let shared = SteppeNotifications()
    static let paneIDKey = "steppe_pane_id"

    private let logger = Logger(subsystem: "dev.steppe.app", category: "SteppeNotifications")

    private var lastStatus: [String: AgentStatus] = [:]
    private var authorized = false
    private var requestedAuthorization = false

    private init() {}

    func reset() {
        lastStatus.removeAll()
    }

    func start(store: HerdrStore) {
        store.onAgentStatusChange = { [weak self] change in
            self?.handle(change)
        }

        guard !requestedAuthorization else { return }
        requestedAuthorization = true

        Task {
            do {
                authorized = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                authorized = false
                logger.error("notification authorization failed: \(error.localizedDescription)")
            }
        }
    }

    private func handle(_ change: AgentStatusChangedEvent) {
        let previous = lastStatus[change.paneId]
        lastStatus[change.paneId] = change.agentStatus

        guard change.agentStatus == .blocked || change.agentStatus == .done else {
            return
        }

        // Only notify on a transition into the attention state, not on every snapshot refresh.
        guard previous != change.agentStatus else { return }
        guard authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = change.displayAgent ?? change.agent ?? "Herdr agent"
        content.body = change.stateLabels?[change.agentStatus.rawValue]
            ?? (change.agentStatus == .blocked ? "needs input" : "finished")
        content.sound = .default
        content.threadIdentifier = "herdr"
        content.userInfo = [
            Self.paneIDKey: change.paneId,
            "steppe_workspace_id": change.workspaceId,
        ]

        let identifier = "steppe-\(change.paneId)-\(change.agentStatus.rawValue)-\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
