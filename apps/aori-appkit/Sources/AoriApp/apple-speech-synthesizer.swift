import AVFoundation
import AoriCore
import Foundation

@MainActor
final class AppleSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate, SpeechSynthesizer {
    var onSpeakingChanged: ((Bool) -> Void)?
    var onMouthLevel: ((Double) -> Void)?
    var onViseme: ((String) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var continuation: CheckedContinuation<Void, Never>?
    private var activeUtteranceID: ObjectIdentifier?
    private var engineReady = false
    private var synthesisDone = false
    private var pendingBuffers = 0
    private var spokenText = ""
    private var playedFrames = 0
    private var sampleRate = 22_050.0
    private var recorded: [Float] = []
    private var visemes: [String] = []
    private var engineFailed = false
    private var artifactsWritten = false

    func speak(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        artifactsWritten = true
        stop()
        synthesizer.delegate = self
        synthesisDone = false
        pendingBuffers = 0
        spokenText = trimmed
        playedFrames = 0
        sampleRate = 22_050
        recorded = []
        visemes = []
        engineFailed = false
        artifactsWritten = false
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
        let samples = Self.samples(of: buffer)
        recorded.append(contentsOf: samples)
        if buffer.format.sampleRate > 0 {
            sampleRate = buffer.format.sampleRate
        }
        let start = sampleRate > 0 ? Double(playedFrames) / sampleRate : 0
        let span = sampleRate > 0 ? Double(buffer.frameLength) / sampleRate : 0
        for preset in VisemeTimeline.presets(in: spokenText, from: start, to: start + span) {
            note(viseme: preset.rawValue)
        }
        playedFrames += Int(buffer.frameLength)
        onMouthLevel?(level)
        if engineFailed {
            return
        }
        guard prepare(format: buffer.format) else {
            engineFailed = true
            return
        }
        pendingBuffers += 1
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
        writeArtifacts()
        onSpeakingChanged?(false)
        guard let continuation else {
            return
        }
        self.continuation = nil
        continuation.resume()
    }

    private func note(viseme: String) {
        if visemes.last != viseme {
            visemes.append(viseme)
        }
        onViseme?(viseme)
    }

    private func writeArtifacts() {
        guard !artifactsWritten else {
            return
        }
        artifactsWritten = true
        let environment = ProcessInfo.processInfo.environment
        if let path = environment["AORI_SPEECH_WAV"], !path.isEmpty, !recorded.isEmpty {
            let wav = WavFile.encode(samples: recorded, sampleRate: Int(sampleRate.rounded()))
            try? wav.write(to: URL(fileURLWithPath: path))
            let rms = WavFile.rms(samples: recorded)
            logLine(String(format: "aori_speech_rms=%.4f", rms))
        }
        if let path = environment["AORI_VISEME_LOG"], !path.isEmpty {
            let body = visemes.isEmpty ? "" : visemes.joined(separator: "\n") + "\n"
            try? Data(body.utf8).write(to: URL(fileURLWithPath: path))
            logLine("aori_visemes=\(visemes.joined(separator: ","))")
        }
        let engine = engineFailed ? "failed" : (engineReady ? "started" : "idle")
        logLine("aori_speech_engine=\(engine)")
    }

    private func logLine(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else {
            return
        }
        FileHandle.standardOutput.write(data)
        try? FileHandle.standardOutput.synchronize()
    }

    private static func samples(of buffer: AVAudioPCMBuffer) -> [Float] {
        let count = Int(buffer.frameLength)
        guard count > 0 else {
            return []
        }
        if let channels = buffer.floatChannelData {
            return Array(UnsafeBufferPointer(start: channels[0], count: count))
        }
        if let channels = buffer.int16ChannelData {
            return (0..<count).map { Float(channels[0][$0]) / Float(Int16.max) }
        }
        return []
    }

    private static func level(of buffer: AVAudioBuffer) -> Double {
        guard let pcm = buffer as? AVAudioPCMBuffer else {
            return 0
        }
        return SpeechLevel.mouthOpen(samples: samples(of: pcm))
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let text = utterance.speechString as NSString
        guard characterRange.location != NSNotFound, characterRange.location < text.length else {
            return
        }
        let unit = text.character(at: characterRange.location)
        let preset: String
        if let scalar = UnicodeScalar(UInt32(unit)) {
            preset = VisemeMap.preset(for: Character(scalar)).rawValue
        } else {
            preset = Viseme.sil.rawValue
        }
        Task { @MainActor in
            self.note(viseme: preset)
        }
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
