import XCTest
@testable import HerdrKit

final class HerdrSessionTests: XCTestCase {
    func testExplicitSocketPathWins() {
        let session = HerdrSession.discover(
            environment: [
                "HERDR_SOCKET_PATH": "/tmp/explicit.sock",
                "HERDR_SESSION": "ignored",
            ],
            home: URL(fileURLWithPath: "/Users/nobody")
        )

        XCTAssertEqual(session.name, "custom")
        XCTAssertEqual(session.socketPath, "/tmp/explicit.sock")
        XCTAssertFalse(session.exists)
    }

    func testNamedSessionPath() {
        let session = HerdrSession.discover(
            environment: ["HERDR_SESSION": "work"],
            home: URL(fileURLWithPath: "/Users/nobody")
        )

        XCTAssertEqual(session.name, "work")
        XCTAssertEqual(
            session.socketPath,
            "/Users/nobody/.config/herdr/sessions/work/herdr.sock"
        )
    }

    func testDefaultSocketPath() {
        let session = HerdrSession.discover(
            environment: [:],
            home: URL(fileURLWithPath: "/Users/nobody")
        )

        XCTAssertEqual(session.name, "default")
        XCTAssertEqual(session.socketPath, "/Users/nobody/.config/herdr/herdr.sock")
    }

    func testExistingSocketIsReported() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let socketDirectory = home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("herdr", isDirectory: true)
        try FileManager.default.createDirectory(at: socketDirectory, withIntermediateDirectories: true)

        let socket = socketDirectory.appendingPathComponent("herdr.sock")
        XCTAssertTrue(FileManager.default.createFile(atPath: socket.path, contents: Data()))

        defer { try? FileManager.default.removeItem(at: home) }

        let session = HerdrSession.discover(environment: [:], home: home)
        XCTAssertTrue(session.exists)
    }

    func testAvailableSessionsFindsNamedSockets() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionsDirectory = home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("herdr", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)

        for name in ["beta", "alpha"] {
            let directory = sessionsDirectory.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let socket = directory.appendingPathComponent("herdr.sock")
            XCTAssertTrue(FileManager.default.createFile(atPath: socket.path, contents: Data()))
        }

        // A directory without a socket should be ignored.
        try FileManager.default.createDirectory(
            at: sessionsDirectory.appendingPathComponent("empty", isDirectory: true),
            withIntermediateDirectories: true
        )

        defer { try? FileManager.default.removeItem(at: home) }

        let sessions = HerdrSession.availableSessions(home: home)
        XCTAssertEqual(sessions.map(\.name), ["alpha", "beta"])
        XCTAssertTrue(sessions.allSatisfy(\.exists))
    }
}
