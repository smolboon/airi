import Foundation

/// One spoken line for VoiceOver. The app logs this text and posts it as an announcement.
public enum SpeechCaption {
    public static func line(for text: String) -> String {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if trimmed.isEmpty {
            return "aori_caption=empty"
        }
        return "aori_caption=\(trimmed)"
    }
}
