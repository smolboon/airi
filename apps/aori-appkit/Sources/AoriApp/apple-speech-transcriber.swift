import AoriCore
import AVFoundation
import Foundation
import Speech

final class AppleSpeechTranscriber: NSObject, VoiceTranscriber, @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var fileTask: SFSpeechRecognitionTask?
    private var tapInstalled = false

    init(locale: Locale = Locale(identifier: "en-US")) {
        recognizer = SFSpeechRecognizer(locale: locale)
        super.init()
    }

    func requestAuthorization() async -> SpeechPermission {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        let mapped = Self.map(speech)
        guard mapped == .granted else {
            return mapped
        }
        let microphone = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return microphone ? .granted : .denied
    }

    func start(
        onPartial: @escaping @Sendable (String) -> Void,
        onSamples: @escaping @Sendable ([Float], Double) -> Void
    ) throws {
        stop()
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechSessionError.recognizerUnavailable
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw SpeechSessionError.microphoneUnavailable
        }
        let rate = format.sampleRate
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
            let samples = Self.samples(of: buffer)
            if !samples.isEmpty {
                onSamples(samples, rate)
            }
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { result, error in
            if let text = result?.bestTranscription.formattedString {
                onPartial(text)
            }
            if error != nil || result?.isFinal == true {
                onPartial(result?.bestTranscription.formattedString ?? "")
            }
        }
    }

    /// Reads a short buffer. The mark is no-device, silence, or speech.
    @MainActor
    func captureUtterance(seconds: Double = 0.4) -> String {
        let probe = AVAudioEngine()
        let input = probe.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            return LiveUtterance.mark(hasDevice: false, sampleCount: 0, speech: false)
        }
        let box = SampleBox()
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            box.append(Self.samples(of: buffer))
        }
        do {
            try probe.start()
        } catch {
            input.removeTap(onBus: 0)
            return LiveUtterance.mark(hasDevice: false, sampleCount: 0, speech: false)
        }
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        probe.stop()
        input.removeTap(onBus: 0)
        let samples = box.copy()
        let activity = VoiceActivity(threshold: 0.02, silenceSeconds: 0.2, sampleRate: format.sampleRate)
        let speech = activity.containsSpeech(samples)
        return LiveUtterance.mark(hasDevice: true, sampleCount: samples.count, speech: speech)
    }

    /// Starts the input engine and stops it. The result is started or unavailable.
    func probeMicrophone() -> String {
        let probe = AVAudioEngine()
        let input = probe.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            return "unavailable"
        }
        input.installTap(onBus: 0, bufferSize: 512, format: format) { _, _ in }
        do {
            try probe.start()
            probe.stop()
            input.removeTap(onBus: 0)
            return "started"
        } catch {
            return "unavailable"
        }
    }

    func authorization(timeout seconds: Double) async -> SpeechPermission {
        let current = Self.map(SFSpeechRecognizer.authorizationStatus())
        if current != .unknown {
            return current
        }
        return await withCheckedContinuation { continuation in
            let gate = ResumeGate()
            let finish: @Sendable (SpeechPermission) -> Void = { status in
                if gate.claim() {
                    continuation.resume(returning: status)
                }
            }
            SFSpeechRecognizer.requestAuthorization { status in
                finish(Self.map(status))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                finish(.unknown)
            }
        }
    }

    func transcribeFile(at url: URL, timeout seconds: Double = 12) async -> String {
        await withCheckedContinuation { continuation in
            let gate = ResumeGate()
            let finish: @Sendable (String) -> Void = { text in
                if gate.claim() {
                    continuation.resume(returning: text)
                }
            }
            guard let recognizer, recognizer.isAvailable else {
                finish("")
                return
            }
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = true
            fileTask = recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    finish(result.bestTranscription.formattedString)
                    return
                }
                if error != nil {
                    finish(result?.bestTranscription.formattedString ?? "")
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                finish("")
            }
        }
    }

    func stop() {
        request?.endAudio()
        stopEngine()
        task?.cancel()
        task = nil
        request = nil
    }

    private func stopEngine() {
        if engine.isRunning {
            engine.stop()
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    private static func samples(of buffer: AVAudioPCMBuffer) -> [Float] {
        let count = Int(buffer.frameLength)
        guard count > 0, let channels = buffer.floatChannelData else {
            return []
        }
        return Array(UnsafeBufferPointer(start: channels[0], count: count))
    }

    private static func map(_ status: SFSpeechRecognizerAuthorizationStatus) -> SpeechPermission {
        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}

private final class SampleBox: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []

    func append(_ next: [Float]) {
        lock.lock()
        samples.append(contentsOf: next)
        lock.unlock()
    }

    func copy() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }
}

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done {
            return false
        }
        done = true
        return true
    }
}
