import Foundation

public struct VisionTickerPolicy: Equatable, Sendable {
    public var enabled: Bool
    public var intervalMilliseconds: Int
    public var maximumTicks: Int

    public init(enabled: Bool, intervalMilliseconds: Int, maximumTicks: Int) {
        self.enabled = enabled
        self.intervalMilliseconds = intervalMilliseconds
        self.maximumTicks = maximumTicks
    }

    public static let minimumMilliseconds = 1000
    public static let maximumAllowedTicks = 8

    public static func resolve(environment: [String: String]) -> VisionTickerPolicy {
        let enabled = environment["AORI_VISION_TICKER"] == "1"
        let requested = Int(environment["AORI_VISION_INTERVAL_MS"] ?? "") ?? 15_000
        let requestedTicks = Int(environment["AORI_VISION_MAX_TICKS"] ?? "") ?? 4
        let interval = max(minimumMilliseconds, requested)
        let ticks = min(maximumAllowedTicks, max(0, requestedTicks))
        return VisionTickerPolicy(enabled: enabled, intervalMilliseconds: interval, maximumTicks: ticks)
    }

    public func allows(tick: Int) -> Bool {
        enabled && tick >= 1 && tick <= maximumTicks
    }
}
