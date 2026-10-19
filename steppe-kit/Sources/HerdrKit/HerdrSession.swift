import Foundation

/// Resolves which Herdr server socket this client should attach to.
///
/// Resolution order mirrors Herdr's own clients:
/// 1. `HERDR_SOCKET_PATH` (explicit low-level override)
/// 2. `HERDR_SESSION` (named session)
/// 3. the default session socket
public struct HerdrSession: Sendable, Equatable {
    public var name: String
    public var socketPath: String
    public var exists: Bool

    public init(name: String, socketPath: String, exists: Bool) {
        self.name = name
        self.socketPath = socketPath
        self.exists = exists
    }

    public static func discover(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> HerdrSession {
        let configDirectory = home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("herdr", isDirectory: true)

        if let explicit = environment["HERDR_SOCKET_PATH"], !explicit.isEmpty {
            return HerdrSession(
                name: "custom",
                socketPath: explicit,
                exists: fileManager.fileExists(atPath: explicit)
            )
        }

        if let named = environment["HERDR_SESSION"], !named.isEmpty {
            let path = configDirectory
                .appendingPathComponent("sessions", isDirectory: true)
                .appendingPathComponent(named, isDirectory: true)
                .appendingPathComponent("herdr.sock")
                .path
            return HerdrSession(name: named, socketPath: path, exists: fileManager.fileExists(atPath: path))
        }

        let path = configDirectory.appendingPathComponent("herdr.sock").path
        return HerdrSession(name: "default", socketPath: path, exists: fileManager.fileExists(atPath: path))
    }

    /// Named sessions that currently have a socket on disk.
    public static func availableSessions(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> [HerdrSession] {
        let base = home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("herdr", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)

        guard let contents = try? fileManager.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { directory -> HerdrSession? in
            guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }
            let socket = directory.appendingPathComponent("herdr.sock").path
            guard fileManager.fileExists(atPath: socket) else { return nil }
            return HerdrSession(name: directory.lastPathComponent, socketPath: socket, exists: true)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
