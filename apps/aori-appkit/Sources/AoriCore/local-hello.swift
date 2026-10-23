#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum LocalHelloError: Error, Equatable, Sendable {
    case refused
    case failed
}

public enum LocalHello {
    /// `127.0.0.1` and `localhost` are the only hosts. No DNS lookup runs.
    public static func allows(_ host: String) -> Bool {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return host == "127.0.0.1" || host == "localhost"
    }

    /// Sends `HELLO <name>` to loopback and reads `OK <name>`.
    public static func exchange(host: String, port: Int, name: String) -> Result<String, LocalHelloError> {
        guard allows(host) else {
            return .failure(.refused)
        }
        guard (1 ... 65535).contains(port) else {
            return .failure(.refused)
        }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSafeName(name) else {
            return .failure(.refused)
        }
        guard let address = Socket.loopbackAddress(port: UInt16(port)) else {
            return .failure(.failed)
        }
        let fd = Socket.open()
        guard fd >= 0 else {
            return .failure(.failed)
        }
        defer { Socket.close(fd) }
        Socket.setTimeouts(fd)
        let connected = Socket.withAddress(address) { pointer, length in
            Socket.connect(fd, pointer, length)
        }
        guard connected == 0 else {
            return .failure(.failed)
        }
        let line = "HELLO \(name)\n"
        guard Socket.sendAll(fd, bytes: Array(line.utf8)) else {
            return .failure(.failed)
        }
        guard let reply = Socket.readLine(fd), reply == "OK \(name)" else {
            return .failure(.failed)
        }
        return .success(reply)
    }

    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 64 && !name.contains(where: \.isNewline)
    }
}

public struct LocalHelloServer: Sendable {
    public let port: Int
    private let fd: Int32

    /// Binds `127.0.0.1` on an ephemeral port. The socket is not public.
    public static func bind() -> LocalHelloServer? {
        let fd = Socket.open()
        guard fd >= 0 else {
            return nil
        }
        Socket.reuse(fd)
        guard let address = Socket.loopbackAddress(port: 0) else {
            Socket.close(fd)
            return nil
        }
        let bound = Socket.withAddress(address) { pointer, length in
            Socket.bind(fd, pointer, length)
        }
        guard bound == 0, Socket.listen(fd) == 0, let port = Socket.port(of: fd) else {
            Socket.close(fd)
            return nil
        }
        return LocalHelloServer(port: port, fd: fd)
    }

    /// Accepts one hello and replies `OK <name>`.
    public func serveOne() -> String? {
        defer { Socket.close(fd) }
        Socket.setTimeouts(fd)
        let client = Socket.accept(fd)
        guard client >= 0 else {
            return nil
        }
        defer { Socket.close(client) }
        Socket.setTimeouts(client)
        guard let line = Socket.readLine(client), line.hasPrefix("HELLO ") else {
            return nil
        }
        let name = String(line.dropFirst("HELLO ".count))
        guard LocalHello.isSafeName(name) else {
            return nil
        }
        let reply = "OK \(name)"
        guard Socket.sendAll(client, bytes: Array("\(reply)\n".utf8)) else {
            return nil
        }
        return reply
    }
}

private enum Socket {
    static func open() -> Int32 {
        #if canImport(Darwin)
        Darwin.socket(AF_INET, SOCK_STREAM, 0)
        #elseif canImport(Glibc)
        Glibc.socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #endif
    }

    static func close(_ fd: Int32) {
        #if canImport(Darwin)
        _ = Darwin.close(fd)
        #elseif canImport(Glibc)
        _ = Glibc.close(fd)
        #endif
    }

    static func bind(_ fd: Int32, _ pointer: UnsafePointer<sockaddr>, _ length: socklen_t) -> Int32 {
        #if canImport(Darwin)
        Darwin.bind(fd, pointer, length)
        #elseif canImport(Glibc)
        Glibc.bind(fd, pointer, length)
        #endif
    }

    static func connect(_ fd: Int32, _ pointer: UnsafePointer<sockaddr>, _ length: socklen_t) -> Int32 {
        #if canImport(Darwin)
        Darwin.connect(fd, pointer, length)
        #elseif canImport(Glibc)
        Glibc.connect(fd, pointer, length)
        #endif
    }

    static func listen(_ fd: Int32) -> Int32 {
        #if canImport(Darwin)
        Darwin.listen(fd, 1)
        #elseif canImport(Glibc)
        Glibc.listen(fd, 1)
        #endif
    }

    static func accept(_ fd: Int32) -> Int32 {
        var pollInfo = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let waited: Int32
        #if canImport(Darwin)
        waited = Darwin.poll(&pollInfo, 1, 1000)
        #elseif canImport(Glibc)
        waited = Glibc.poll(&pollInfo, 1, 1000)
        #endif
        guard waited > 0 else {
            return -1
        }
        #if canImport(Darwin)
        return Darwin.accept(fd, nil, nil)
        #elseif canImport(Glibc)
        return Glibc.accept(fd, nil, nil)
        #endif
    }

    static func loopbackAddress(port: UInt16) -> sockaddr_in? {
        var ip = in_addr()
        let parsed = "127.0.0.1".withCString { cString in
            #if canImport(Darwin)
            Darwin.inet_pton(AF_INET, cString, &ip)
            #elseif canImport(Glibc)
            Glibc.inet_pton(AF_INET, cString, &ip)
            #endif
        }
        guard parsed == 1 else {
            return nil
        }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = ip
        return address
    }

    static func withAddress<T>(_ address: sockaddr_in, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
        var address = address
        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                body(rebound, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    static func port(of fd: Int32) -> Int? {
        var address = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                #if canImport(Darwin)
                Darwin.getsockname(fd, rebound, &length)
                #elseif canImport(Glibc)
                Glibc.getsockname(fd, rebound, &length)
                #endif
            }
        }
        guard result == 0 else {
            return nil
        }
        return Int(UInt16(bigEndian: address.sin_port))
    }

    static func reuse(_ fd: Int32) {
        var yes: Int32 = 1
        _ = withUnsafePointer(to: &yes) { pointer in
            #if canImport(Darwin)
            Darwin.setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, pointer, socklen_t(MemoryLayout<Int32>.size))
            #elseif canImport(Glibc)
            Glibc.setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, pointer, socklen_t(MemoryLayout<Int32>.size))
            #endif
        }
    }

    static func setTimeouts(_ fd: Int32) {
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        let size = socklen_t(MemoryLayout<timeval>.size)
        withUnsafePointer(to: &timeout) { pointer in
            #if canImport(Darwin)
            _ = Darwin.setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, pointer, size)
            _ = Darwin.setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, pointer, size)
            #elseif canImport(Glibc)
            _ = Glibc.setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, pointer, size)
            _ = Glibc.setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, pointer, size)
            #endif
        }
    }

    static func sendAll(_ fd: Int32, bytes: [UInt8]) -> Bool {
        bytes.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else {
                return false
            }
            var sent = 0
            while sent < raw.count {
                let count: Int
                #if canImport(Darwin)
                count = Darwin.send(fd, base.advanced(by: sent), raw.count - sent, 0)
                #elseif canImport(Glibc)
                count = Int(Glibc.send(fd, base.advanced(by: sent), raw.count - sent, 0))
                #endif
                if count <= 0 {
                    return false
                }
                sent += count
            }
            return true
        }
    }

    static func readLine(_ fd: Int32) -> String? {
        var bytes: [UInt8] = []
        while bytes.count < 80 {
            var byte: UInt8 = 0
            let count: Int
            #if canImport(Darwin)
            count = withUnsafeMutablePointer(to: &byte) { pointer in
                Darwin.recv(fd, pointer, 1, 0)
            }
            #elseif canImport(Glibc)
            count = withUnsafeMutablePointer(to: &byte) { pointer in
                Int(Glibc.recv(fd, pointer, 1, 0))
            }
            #endif
            if count <= 0 {
                return nil
            }
            if byte == 10 {
                if bytes.last == 13 {
                    bytes.removeLast()
                }
                return String(bytes: bytes, encoding: .utf8)
            }
            bytes.append(byte)
        }
        return nil
    }
}
