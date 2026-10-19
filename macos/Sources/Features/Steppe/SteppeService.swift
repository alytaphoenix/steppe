import Combine
import Foundation

/// Owns the single Herdr connection used by the Steppe chrome.
///
/// The store starts lazily when the first terminal window asks for the sidebar. The terminal
/// surface itself is unchanged: Herdr still runs inside it, and this object only mirrors Herdr's
/// workspaces, panes, and agents over the local socket.
@MainActor
final class SteppeService: ObservableObject {
    static let shared = SteppeService()

    let store: HerdrStore
    @Published var isSidebarVisible = true

    private init() {
        let session = HerdrSession.discover()
        store = HerdrStore(session: session)
        store.start()
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }
}
