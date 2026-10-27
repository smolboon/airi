import Foundation

public struct RuntimeSample: Equatable, Sendable {
    public var framesPerSecond: Double
    public var latencyMilliseconds: Double
    public var memoryMegabytes: Double

    public init(framesPerSecond: Double, latencyMilliseconds: Double, memoryMegabytes: Double) {
        self.framesPerSecond = framesPerSecond
        self.latencyMilliseconds = latencyMilliseconds
        self.memoryMegabytes = memoryMegabytes
    }
}

public enum RuntimeMetrics {
    /// Frames per second for one captured frame.
    public static func framesPerSecond(frameMilliseconds: Double) -> Double {
        guard frameMilliseconds > 0 else {
            return 0
        }
        return 1000 / frameMilliseconds
    }

    public static func lines(_ sample: RuntimeSample) -> [String] {
        [
            String(format: "aori_fps=%.2f", sample.framesPerSecond),
            String(format: "aori_latency_ms=%.2f", sample.latencyMilliseconds),
            String(format: "aori_memory_mb=%.2f", sample.memoryMegabytes),
        ]
    }

    /// Resident memory in megabytes. Zero means the read failed.
    public static func memoryMegabytes() -> Double {
        #if os(macOS)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return 0
        }
        return Double(info.resident_size) / (1024 * 1024)
        #else
        guard let text = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8) else {
            return 0
        }
        for line in text.split(separator: "\n") where line.hasPrefix("VmRSS:") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.count >= 2, let kilobytes = Double(parts[1]) {
                return kilobytes / 1024
            }
        }
        return 0
        #endif
    }
}
