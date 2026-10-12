import Foundation

/// English UI copy for the native shell. Other locales are not in this table.
public enum AoriCopy {
    public static let appName = "Aori"
    public static let about = "About Aori"
    public static let settings = "Settings…"
    public static let quit = "Quit Aori"
    public static let newChat = "New Chat"
    public static let openVRM = "Open VRM…"
    public static let showMainWindow = "Show Main Window"
    public static let showCompanion = "Show Companion"
    public static let hideCompanion = "Hide Companion"
    public static let alwaysOnTop = "Companion Always on Top"
    public static let statusItem = "Aori"
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

public enum ScreenshotPose {
    public static let samples: [Float] = [Float](repeating: 0.25, count: 16)
    public static let time = MotionPolicy.screenshotTime

    public static var mouthOpen: Double {
        SpeechLevel.mouthOpen(samples: samples)
    }
}
