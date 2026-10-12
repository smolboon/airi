import AVFoundation
import AoriCore
import Foundation

@MainActor
final class AppleSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate, SpeechSynthesizer {
    var onSpeakingChanged: ((Bool) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private var activeUtteranceID: ObjectIdentifier?

    func speak(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        stop()
        synthesizer.delegate = self
        onSpeakingChanged?(true)
        let utterance = AVSpeechUtterance(string: trimmed)
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        activeUtteranceID = ObjectIdentifier(utterance)
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        activeUtteranceID = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finishSpeaking()
    }

    private func finishSpeaking() {
        onSpeakingChanged?(false)
        guard let continuation else {
            return
        }
        self.continuation = nil
        continuation.resume()
    }

    private func finishIfCurrent(_ utteranceID: ObjectIdentifier) {
        guard utteranceID == activeUtteranceID else {
            return
        }
        activeUtteranceID = nil
        finishSpeaking()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.finishIfCurrent(utteranceID)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.finishIfCurrent(utteranceID)
        }
    }
}
