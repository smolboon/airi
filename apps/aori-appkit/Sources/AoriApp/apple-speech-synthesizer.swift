import AVFoundation
import AoriCore
import Foundation

@MainActor
final class AppleSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate, SpeechSynthesizer {
    var onSpeakingChanged: ((Bool) -> Void)?
    var onMouthLevel: ((Double) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var continuation: CheckedContinuation<Void, Never>?
    private var activeUtteranceID: ObjectIdentifier?
    private var engineReady = false
    private var synthesisDone = false
    private var pendingBuffers = 0

    func speak(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        stop()
        synthesizer.delegate = self
        synthesisDone = false
        pendingBuffers = 0
        onSpeakingChanged?(true)
        let utterance = AVSpeechUtterance(string: trimmed)
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        let utteranceID = ObjectIdentifier(utterance)
        activeUtteranceID = utteranceID
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.write(utterance) { [weak self] buffer in
                let level = Self.level(of: buffer)
                let pcm = buffer as? AVAudioPCMBuffer
                Task { @MainActor in
                    self?.receive(buffer: pcm, level: level, utteranceID: utteranceID)
                }
            }
        }
    }

    func stop() {
        activeUtteranceID = nil
        synthesisDone = true
        pendingBuffers = 0
        player.stop()
        engine.stop()
        engine.reset()
        engineReady = false
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        onMouthLevel?(0)
        finishSpeaking()
    }

    private func receive(buffer: AVAudioPCMBuffer?, level: Double, utteranceID: ObjectIdentifier) {
        guard utteranceID == activeUtteranceID else {
            return
        }
        guard let buffer, buffer.frameLength > 0 else {
            synthesisDone = true
            finishIfPlaybackEnded()
            return
        }
        guard prepare(format: buffer.format) else {
            finishSpeaking()
            return
        }
        pendingBuffers += 1
        onMouthLevel?(level)
        player.scheduleBuffer(buffer, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, utteranceID == self.activeUtteranceID else {
                    return
                }
                self.pendingBuffers = max(0, self.pendingBuffers - 1)
                self.onMouthLevel?(0)
                self.finishIfPlaybackEnded()
            }
        })
    }

    private func prepare(format: AVAudioFormat) -> Bool {
        if engineReady {
            return true
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            return false
        }
        player.play()
        engineReady = true
        return true
    }

    private func finishIfPlaybackEnded() {
        guard synthesisDone, pendingBuffers == 0 else {
            return
        }
        activeUtteranceID = nil
        onMouthLevel?(0)
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

    private static func level(of buffer: AVAudioBuffer) -> Double {
        guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
            return 0
        }
        let count = Int(pcm.frameLength)
        if let channels = pcm.floatChannelData {
            let samples = Array(UnsafeBufferPointer(start: channels[0], count: count))
            return SpeechLevel.mouthOpen(samples: samples)
        }
        if let channels = pcm.int16ChannelData {
            let samples = (0..<count).map { Float(channels[0][$0]) / Float(Int16.max) }
            return SpeechLevel.mouthOpen(samples: samples)
        }
        return 0
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard utteranceID == self.activeUtteranceID else {
                return
            }
            self.synthesisDone = true
            self.finishIfPlaybackEnded()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard utteranceID == self.activeUtteranceID else {
                return
            }
            self.activeUtteranceID = nil
            self.pendingBuffers = 0
            self.onMouthLevel?(0)
            self.finishSpeaking()
        }
    }
}
