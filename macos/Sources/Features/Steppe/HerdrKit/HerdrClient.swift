import Foundation

public final class HerdrClient: @unchecked Sendable {
    public let socketPath: String

    // Requests and subscriptions use separate serial queues: a subscription blocks on a
    // long-lived read, and sharing a queue with requests would starve snapshot refreshes.
    private let requestQueue = DispatchQueue(label: "dev.steppe.herdr.requests", qos: .userInitiated)
    private let eventQueue = DispatchQueue(label: "dev.steppe.herdr.events", qos: .userInitiated)

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    public static func discover(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> HerdrClient {
        HerdrClient(socketPath: HerdrSession.discover(environment: environment, home: home).socketPath)
    }

    // MARK: - Queries

    public func snapshot() async throws -> SessionSnapshot {
        let result: SnapshotResult = try await request("session.snapshot", params: .object([:]))
        return result.snapshot
    }

    public func ping() async throws -> PongResult {
        try await request("ping", params: .object([:]))
    }

    public func agents() async throws -> [AgentInfo] {
        let result: AgentListResult = try await request("agent.list", params: .object([:]))
        return result.agents
    }

    // MARK: - Actions

    public func focusWorkspace(_ workspaceId: String) async throws {
        let _: AckResult = try await request(
            "workspace.focus",
            params: .object(["workspace_id": .string(workspaceId)])
        )
    }

    public func focusTab(_ tabId: String) async throws {
        let _: AckResult = try await request(
            "tab.focus",
            params: .object(["tab_id": .string(tabId)])
        )
    }

    public func focusPane(_ paneId: String) async throws {
        let _: AckResult = try await request(
            "pane.focus",
            params: .object(["pane_id": .string(paneId)])
        )
    }

    public func focusAgent(_ target: String) async throws {
        let _: AckResult = try await request(
            "agent.focus",
            params: .object(["target": .string(target)])
        )
    }

    // MARK: - Events

    /// Opens a long-lived subscription. The caller treats events as invalidation signals and
    /// refreshes an authoritative snapshot; that avoids depending on every event payload shape.
    public func events(subscriptions: [String]) -> AsyncThrowingStream<HerdrEvent, Error> {
        let requestData: Data
        do {
            requestData = try Self.encodeRequest(
                method: "events.subscribe",
                params: .object([
                    "subscriptions": .array(
                        subscriptions.map { .object(["type": .string($0)]) }
                    ),
                ])
            )
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        return AsyncThrowingStream { continuation in
            let socketBox = SocketBox()
            let cancellation = CancellationBox()

            continuation.onTermination = { _ in
                cancellation.cancel()
                socketBox.close()
            }

            eventQueue.async {
                do {
                    let socket = try HerdrSocket.connect(path: self.socketPath)
                    socketBox.store(socket)

                    guard !cancellation.isCancelled else {
                        socketBox.close()
                        continuation.finish()
                        return
                    }

                    try socket.writeLine(requestData)

                    guard let acknowledgement = try socket.readLine() else {
                        throw HerdrSocketError.unexpectedEOF
                    }

                    let envelope = try JSONDecoder.herdr.decode(
                        ResponseEnvelope<AckResult>.self,
                        from: acknowledgement
                    )

                    if let error = envelope.error {
                        throw error
                    }

                    while !cancellation.isCancelled {
                        guard let line = try socket.readLine() else {
                            break
                        }

                        if let event = try? JSONDecoder.herdr.decode(HerdrEvent.self, from: line) {
                            continuation.yield(event)
                        }
                    }

                    continuation.finish()
                } catch {
                    if !cancellation.isCancelled {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }

                socketBox.close()
            }
        }
    }

    // MARK: - Transport

    private func request<Result: Codable & Sendable>(
        _ method: String,
        params: JSONValue
    ) async throws -> Result {
        let requestData = try Self.encodeRequest(method: method, params: params)

        return try await withCheckedThrowingContinuation { continuation in
            requestQueue.async {
                do {
                    let socket = try HerdrSocket.connect(path: self.socketPath)
                    defer { socket.close() }

                    try socket.writeLine(requestData)

                    guard let line = try socket.readLine() else {
                        throw HerdrSocketError.unexpectedEOF
                    }

                    let envelope: ResponseEnvelope<Result>
                    do {
                        envelope = try JSONDecoder.herdr.decode(ResponseEnvelope<Result>.self, from: line)
                    } catch {
                        let raw = String(data: line, encoding: .utf8) ?? "<non-UTF8>"
                        throw HerdrSocketError.malformedResponse(raw)
                    }

                    if let error = envelope.error {
                        throw error
                    }

                    guard let result = envelope.result else {
                        throw HerdrSocketError.malformedResponse("missing result")
                    }

                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func encodeRequest(method: String, params: JSONValue) throws -> Data {
        let request = JSONValue.object([
            "id": .string(UUID().uuidString.lowercased()),
            "method": .string(method),
            "params": params,
        ])
        return try JSONEncoder().encode(request)
    }
}

private final class SocketBox: @unchecked Sendable {
    private let lock = NSLock()
    private var socket: HerdrSocket?
    private var closed = false

    func store(_ socket: HerdrSocket) {
        lock.lock()
        if closed {
            lock.unlock()
            socket.close()
            return
        }
        self.socket = socket
        lock.unlock()
    }

    func close() {
        lock.lock()
        closed = true
        let socket = self.socket
        self.socket = nil
        lock.unlock()
        socket?.close()
    }
}

private final class CancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}
