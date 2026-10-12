import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// English UI copy for the native shell. `load` reads `packages/i18n` before the menu is built.
public enum AoriCopy {
    private static let storage = CopyStorage()

    public static func load(_ text: String) {
        let parsed = LocaleTable.parse(text).values
        storage.lock.lock()
        storage.values = parsed
        storage.lock.unlock()
    }

    public static var appName: String { text("menu.appName", fallback: "Aori") }
    public static var about: String { text("menu.about", fallback: "About Aori") }
    public static var settings: String { text("menu.settings", fallback: "Settings…") }
    public static var quit: String { text("menu.quit", fallback: "Quit Aori") }
    public static var newChat: String { text("menu.newChat", fallback: "New Chat") }
    public static var openVRM: String { text("menu.openVRM", fallback: "Open VRM…") }
    public static var showMainWindow: String { text("menu.showMainWindow", fallback: "Show Main Window") }
    public static var showCompanion: String { text("menu.showCompanion", fallback: "Show Companion") }
    public static var hideCompanion: String { text("menu.hideCompanion", fallback: "Hide Companion") }
    public static var alwaysOnTop: String { text("menu.alwaysOnTop", fallback: "Companion Always on Top") }
    public static var clickThrough: String { text("menu.clickThrough", fallback: "Click Through") }
    public static var language: String { text("menu.language", fallback: "Language") }
    public static var statusItem: String { text("menu.statusItem", fallback: "Aori") }

    private static func text(_ key: String, fallback: String) -> String {
        storage.lock.lock()
        let value = storage.values[key]
        storage.lock.unlock()
        return value ?? fallback
    }
}

private final class CopyStorage: @unchecked Sendable {
    let lock = NSLock()
    var values: [String: String] = [:]
}

public enum MotionPolicy {
    /// Fixed clock for the CI capture. The neck clip is off identity at this time.
    public static let screenshotTime = 1.6

    public static func idleTime(time: Double, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : time
    }

    public static func blink(time: Double, reduceMotion: Bool) -> Double {
        if reduceMotion {
            return 0
        }
        var remainder = time.truncatingRemainder(dividingBy: 3.2)
        if remainder < 0 {
            remainder += 3.2
        }
        return abs(remainder - 0.1) < 0.08 ? 1 : 0
    }
}

public enum LookAt {
    /// Eye yaw and pitch in radians. Reduce motion holds the eyes at rest.
    public static func offset(time: Double, reduceMotion: Bool) -> (x: Double, y: Double) {
        if reduceMotion {
            return (0, 0)
        }
        return (sin(time * 0.7) * 0.35, sin(time * 0.35) * 0.12)
    }
}

public enum ScreenshotPose {
    public static let samples: [Float] = [Float](repeating: 0.25, count: 16)
    public static let time = MotionPolicy.screenshotTime

    public static var mouthOpen: Double {
        SpeechLevel.mouthOpen(samples: samples)
    }
}
