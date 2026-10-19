import AppKit
import HerdrKit
import SwiftUI

@main
struct SteppeSpikeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: HerdrStore

    init() {
        let session = HerdrSession.discover()
        _store = StateObject(wrappedValue: HerdrStore(session: session))
    }

    var body: some Scene {
        WindowGroup("Steppe") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 560)
                .task {
                    store.start()
                }
        }
        .defaultSize(width: 1120, height: 720)
        .windowToolbarStyle(.unified)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
