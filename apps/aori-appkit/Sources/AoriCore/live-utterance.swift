import Foundation

/// Marks a short microphone capture. No device, silence, and speech are different.
public enum LiveUtterance {
    public static func mark(hasDevice: Bool, sampleCount: Int, speech: Bool) -> String {
        if !hasDevice {
            return "no-device"
        }
        if sampleCount > 0 && speech {
            return "speech"
        }
        return "silence"
    }
}
