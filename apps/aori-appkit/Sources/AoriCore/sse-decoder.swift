import Foundation

public struct SSEEvent: Equatable, Sendable {
    public var event: String
    public var data: String

    public init(event: String = "message", data: String) {
        self.event = event
        self.data = data
    }
}

public struct SSEDecoder: Sendable {
    private var buffer = ""

    public init() {}

    public mutating func feed(_ chunk: String) -> [SSEEvent] {
        buffer.append(chunk)
        var events: [SSEEvent] = []
        while let boundary = Self.boundary(in: buffer) {
            let block = String(buffer[..<boundary.blockEnd])
            buffer.removeSubrange(buffer.startIndex..<boundary.consumeEnd)
            if let event = Self.parse(block) {
                events.append(event)
            }
        }
        return events
    }

    /// Parses a trailing event when the server closes without a blank line.
    public mutating func finish() -> [SSEEvent] {
        let tail = buffer
        buffer = ""
        guard !tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        if let event = Self.parse(tail) {
            return [event]
        }
        return []
    }

    private struct Boundary {
        var blockEnd: String.Index
        var consumeEnd: String.Index
    }

    private static func boundary(in text: String) -> Boundary? {
        let crlf = text.range(of: "\r\n\r\n")
        let lf = text.range(of: "\n\n")
        switch (crlf, lf) {
        case let (crlf?, lf?) where crlf.lowerBound <= lf.lowerBound:
            return Boundary(blockEnd: crlf.lowerBound, consumeEnd: crlf.upperBound)
        case let (_, lf?):
            return Boundary(blockEnd: lf.lowerBound, consumeEnd: lf.upperBound)
        case let (crlf?, nil):
            return Boundary(blockEnd: crlf.lowerBound, consumeEnd: crlf.upperBound)
        case (nil, nil):
            return nil
        }
    }

    private static func parse(_ block: String) -> SSEEvent? {
        var eventName = "message"
        var dataLines: [String] = []
        let normalized = block.replacingOccurrences(of: "\r\n", with: "\n")
        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = rawLine
            if line.last == "\r" {
                line = line.dropLast()
            }
            if line.isEmpty || line.hasPrefix(":") {
                continue
            }
            if line.hasPrefix("event:") {
                eventName = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.hasPrefix("data:") {
                var value = line.dropFirst("data:".count)
                if value.first == " " {
                    value = value.dropFirst()
                }
                dataLines.append(String(value))
            }
        }
        guard !dataLines.isEmpty else {
            return nil
        }
        return SSEEvent(event: eventName, data: dataLines.joined(separator: "\n"))
    }
}
