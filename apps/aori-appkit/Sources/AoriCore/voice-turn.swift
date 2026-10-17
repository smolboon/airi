import Foundation

public struct VoiceActivity: Equatable, Sendable {
    public var threshold: Double
    public var silenceSeconds: Double
    public var sampleRate: Double

    public init(threshold: Double, silenceSeconds: Double, sampleRate: Double) {
        self.threshold = threshold
        self.silenceSeconds = silenceSeconds
        self.sampleRate = sampleRate
    }

    public static let standard = VoiceActivity(threshold: 0.02, silenceSeconds: 0.45, sampleRate: 22_050)

    /// True when one short window is louder than the threshold.
    public func containsSpeech(_ samples: [Float]) -> Bool {
        let window = max(1, Int(sampleRate * 0.05))
        var index = 0
        while index < samples.count {
            let end = min(samples.count, index + window)
            if WavFile.rms(samples: Array(samples[index..<end])) >= threshold {
                return true
            }
            index += window
        }
        return false
    }

    /// True after speech and a quiet tail. The caller then ends the utterance.
    public func endpoint(_ samples: [Float]) -> Bool {
        guard containsSpeech(samples) else {
            return false
        }
        let silenceCount = max(1, Int(silenceSeconds * sampleRate))
        let speechCount = max(1, Int(0.15 * sampleRate))
        guard samples.count >= silenceCount + speechCount else {
            return false
        }
        let tail = Array(samples.suffix(silenceCount))
        return WavFile.rms(samples: tail) < threshold
    }
}

public struct VoiceTurn: Equatable, Sendable {
    public enum Phase: String, Equatable, Sendable {
        case listening
        case sending
        case speaking
    }

    public enum Action: Equatable, Sendable {
        case none
        case send(String)
        case speak(String)
    }

    public private(set) var phase: Phase = .listening

    public init() {}

    /// Moves from listening to sending. This path does not use a Speak control.
    public mutating func hear(utterance: String) -> Action {
        let text = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .listening, !text.isEmpty else {
            return .none
        }
        phase = .sending
        return .send(text)
    }

    public mutating func acceptReply(_ text: String) -> Action {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .sending, !trimmed.isEmpty else {
            return .none
        }
        phase = .speaking
        return .speak(trimmed)
    }

    public mutating func finishSpeech() {
        phase = .listening
    }
}
