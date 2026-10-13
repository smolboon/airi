import Foundation
import os

enum RuntimeSignpost {
    private static let logger = Logger(subsystem: "ai.moeru.aori.appkit", category: "metrics")
    private static let poster = OSSignposter(subsystem: "ai.moeru.aori.appkit", category: "metrics")

    static func record(_ sample: RuntimeSample) {
        let state = poster.beginInterval("metrics")
        let text = RuntimeMetrics.lines(sample).joined(separator: " ")
        logger.info("\(text, privacy: .public)")
        poster.endInterval("metrics", state)
    }
}
