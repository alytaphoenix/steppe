import Foundation
import Darwin

public enum HerdrSocketError: Error, Sendable, LocalizedError {
    case pathTooLong(String)
    case connectFailed(path: String, code: Int32)
    case writeFailed(code: Int32)
    case readFailed(code: Int32)
    case unexpectedEOF
    case malformedResponse(String)
    case server(String)

    public var errorDescription: String? {
        switch self {
        case .pathTooLong(let path):
            "Herdr socket path is too long: \(path)"
        case .connectFailed(let path, let code):
            "Could not connect to Herdr at \(path): \(String(cString: strerror(code)))"
        case .writeFailed(let code):
            "Could not write to Herdr: \(String(cString: strerror(code)))"
        case .readFailed(let code):
            "Could not read from Herdr: \(String(cString: strerror(code)))"
        case .unexpectedEOF:
            "Herdr closed the connection unexpectedly"
        case .malformedResponse(let detail):
            "Unexpected Herdr response: \(detail)"
        case .server(let message):
            message
        }
    }
}

/// A buffered, newline-framed Unix domain socket.
///
/// A new connection is opened per request. Event subscriptions hold one connection open.
final class HerdrSocket: @unchecked Sendable {
    private let fd: Int32
    private let lock = NSLock()
    private var closed = false
    private var buffer = Data()

    private init(fd: Int32) {
        self.fd = fd
    }

    static func connect(path: String) throws -> HerdrSocket {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count < capacity else {
            throw HerdrSocketError.pathTooLong(path)
        }

        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            destination.initializeMemory(as: UInt8.self, repeating: 0)
            destination.copyBytes(from: pathBytes)
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw HerdrSocketError.connectFailed(path: path, code: errno)
        }

        var noSigPipe: Int32 = 1
        _ = setsockopt(
            fd,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSigPipe,
            socklen_t(MemoryLayout<Int32>.size)
        )

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.connect(fd, socketAddress, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            let code = errno
            Darwin.close(fd)
            throw HerdrSocketError.connectFailed(path: path, code: code)
        }

        return HerdrSocket(fd: fd)
    }

    func writeLine(_ data: Data) throws {
        var payload = data
        payload.append(0x0A)

        try payload.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }

            var offset = 0
            while offset < rawBuffer.count {
                let written = Darwin.write(
                    fd,
                    baseAddress.advanced(by: offset),
                    rawBuffer.count - offset
                )

                if written < 0 {
                    if errno == EINTR { continue }
                    throw HerdrSocketError.writeFailed(code: errno)
                }

                if written == 0 {
                    throw HerdrSocketError.writeFailed(code: EPIPE)
                }

                offset += written
            }
        }
    }

    /// Returns one newline-delimited frame, or nil at EOF.
    func readLine() throws -> Data? {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let line = Data(buffer[buffer.startIndex..<newline])
                buffer.removeSubrange(buffer.startIndex...newline)
                if line.isEmpty { continue }
                return line
            }

            var chunk = [UInt8](repeating: 0, count: 16 * 1024)
            let count = chunk.withUnsafeMutableBytes { rawBuffer in
                Darwin.read(fd, rawBuffer.baseAddress, rawBuffer.count)
            }

            if count < 0 {
                if errno == EINTR { continue }
                throw HerdrSocketError.readFailed(code: errno)
            }

            if count == 0 {
                return nil
            }

            buffer.append(contentsOf: chunk.prefix(count))
        }
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }

        guard !closed else { return }
        closed = true
        _ = Darwin.shutdown(fd, SHUT_RDWR)
        _ = Darwin.close(fd)
    }

    deinit {
        close()
    }
}
