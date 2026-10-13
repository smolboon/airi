import Foundation

public enum SpeechPermission: String, Equatable, Sendable {
    case unknown
    case granted
    case denied
    case restricted
}

public enum SpeechAuthLog {
    /// `authorized` when Speech grants access. `whisper` when the local model runs instead.
    public static func line(permission: SpeechPermission, whisperAvailable: Bool) -> String {
        if permission == .granted {
            return "aori_stt_auth=authorized"
        }
        if whisperAvailable {
            return "aori_stt_auth=whisper"
        }
        return "aori_stt_auth=\(permission.rawValue)"
    }
}

public enum SpeechSessionError: Error, Equatable, Sendable, CustomStringConvertible {
    case recognizerUnavailable
    case microphoneUnavailable
    case emptySpeech

    public var description: String {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is not available."
        case .microphoneUnavailable:
            return "The microphone is not available."
        case .emptySpeech:
            return "No speech was heard."
        }
    }
}

/// Platform speech output. The macOS app uses `AVSpeechSynthesizer`.
@MainActor
public protocol SpeechSynthesizer: AnyObject {
    func speak(_ text: String) async
    func stop()
}

/// Platform speech input. The macOS app uses the Speech framework.
/// The name is not `SpeechTranscriber`. That name is an Apple class on newer SDKs.
public protocol VoiceTranscriber: AnyObject, Sendable {
    func requestAuthorization() async -> SpeechPermission
    func start(
        onPartial: @escaping @Sendable (String) -> Void,
        onSamples: @escaping @Sendable ([Float], Double) -> Void
    ) throws
    func stop()
}
