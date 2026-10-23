public enum MinecraftLink {
    public struct Hello: Equatable, Sendable {
        public var username: String
        public var reply: String
    }

    /// Sends a local hello. A remote host is refused. No password is read.
    public static func hello(host: String, port: Int, username: String) -> Result<Hello, LocalHelloError> {
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isUsername(username) else {
            return .failure(.refused)
        }
        switch LocalHello.exchange(host: host, port: port, name: username) {
        case .success(let reply):
            return .success(Hello(username: username, reply: reply))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// A username has 1 to 16 letters, numbers, or underscores.
    public static func isUsername(_ name: String) -> Bool {
        guard (1 ... 16).contains(name.count) else {
            return false
        }
        return name.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "A" ... "Z", "a" ... "z", "0" ... "9", "_":
                return true
            default:
                return false
            }
        }
    }
}
