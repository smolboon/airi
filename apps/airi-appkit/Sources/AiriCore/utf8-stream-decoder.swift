import Foundation

/// Keeps a split UTF-8 sequence until the next chunk completes it.
public struct UTF8StreamDecoder: Sendable {
    private var pending = Data()

    public init() {}

    public mutating func feed(_ chunk: Data) -> String {
        pending.append(chunk)
        return drain(finish: false)
    }

    public mutating func finish() -> String {
        drain(finish: true)
    }

    private mutating func drain(finish: Bool) -> String {
        guard !pending.isEmpty else {
            return ""
        }
        if let text = String(data: pending, encoding: .utf8) {
            pending.removeAll(keepingCapacity: !finish)
            return text
        }
        let dropLimit = min(3, pending.count - 1)
        guard !finish, dropLimit >= 1 else {
            pending.removeAll(keepingCapacity: false)
            return ""
        }
        for drop in 1...dropLimit {
            let end = pending.count - drop
            let prefix = pending.prefix(end)
            if let text = String(data: prefix, encoding: .utf8) {
                pending.removeFirst(end)
                return text
            }
        }
        return ""
    }
}
