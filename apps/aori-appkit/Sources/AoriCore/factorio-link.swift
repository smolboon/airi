public enum FactorioLink {
    public struct Hello: Equatable, Sendable {
        public var player: String
        public var reply: String
    }

    /// Sends a local hello. A remote host is refused. No password is read.
    public static func hello(host: String, port: Int, player: String) -> Result<Hello, LocalHelloError> {
        let player = player.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LocalHello.isSafeName(player) else {
            return .failure(.refused)
        }
        switch LocalHello.exchange(host: host, port: port, name: player) {
        case .success(let reply):
            return .success(Hello(player: player, reply: reply))
        case .failure(let error):
            return .failure(error)
        }
    }
}
