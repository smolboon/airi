import Foundation

/// Labels for VoiceOver. The app logs `proof` and the live accessibility labels.
public enum AccessibilityCopy {
    public static let transcript = "Chat transcript"
    public static let search = "Search chat"
    public static let message = "Message"
    public static let status = "Status"
    public static let send = "Send message"
    public static let speak = "Speak the last reply"
    public static let listen = "Listen with the microphone"
    public static let character = "Companion character"
    public static let companionWindow = "Companion window"
    public static let chatWindow = "Chat window"
    public static let apiKey = "API key"

    public static var proof: String {
        [
            transcript,
            search,
            message,
            status,
            send,
            speak,
            listen,
            character,
            companionWindow,
            chatWindow,
            apiKey,
        ].joined(separator: "|")
    }
}
