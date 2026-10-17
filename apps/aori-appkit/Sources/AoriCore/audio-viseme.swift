import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Mouth presets from PCM amplitude and zero crossings. This path has no word list.
public enum AudioViseme {
    public struct Frame: Equatable, Sendable {
        public var viseme: Viseme
        public var rms: Double
        public var zeroCrossingRate: Double

        public init(viseme: Viseme, rms: Double, zeroCrossingRate: Double) {
            self.viseme = viseme
            self.rms = rms
            self.zeroCrossingRate = zeroCrossingRate
        }
    }

    public static func frames(samples: [Float], sampleRate: Double) -> [Frame] {
        let window = max(1, Int(sampleRate * 0.02))
        var result: [Frame] = []
        var index = 0
        while index < samples.count {
            let end = min(samples.count, index + window)
            let slice = Array(samples[index..<end])
            let rms = WavFile.rms(samples: slice)
            let rate = zeroCrossingRate(slice)
            result.append(Frame(viseme: classify(rms: rms, zeroCrossingRate: rate), rms: rms, zeroCrossingRate: rate))
            index += window
        }
        return result
    }

    public static func presets(samples: [Float], sampleRate: Double) -> [Viseme] {
        var result: [Viseme] = []
        for frame in frames(samples: samples, sampleRate: sampleRate) {
            if result.last != frame.viseme {
                result.append(frame.viseme)
            }
        }
        return result.isEmpty ? [.sil] : result
    }

    /// One ARPAbet stand-in for a mouth preset. The symbol comes from the frame, not from a word.
    public static func phoneme(for viseme: Viseme) -> String {
        switch viseme {
        case .a:
            return "AA"
        case .e:
            return "EH"
        case .i:
            return "IH"
        case .o:
            return "OW"
        case .u:
            return "UW"
        case .pp:
            return "P"
        case .sil:
            return "SIL"
        }
    }

    public static func phonemes(samples: [Float], sampleRate: Double) -> [String] {
        var result: [String] = []
        for preset in presets(samples: samples, sampleRate: sampleRate) {
            result.append(phoneme(for: preset))
        }
        return result
    }

    public static func tone(frequency: Double, amplitude: Float, sampleRate: Double, count: Int) -> [Float] {
        guard count > 0, sampleRate > 0 else {
            return []
        }
        return (0..<count).map { index in
            let angle = 2 * Double.pi * frequency * Double(index) / sampleRate
            return amplitude * Float(sin(angle))
        }
    }

    private static func classify(rms: Double, zeroCrossingRate: Double) -> Viseme {
        if rms < 0.02 {
            return .sil
        }
        if rms < 0.08 && zeroCrossingRate < 0.08 {
            return .pp
        }
        if zeroCrossingRate >= 0.30 {
            return .i
        }
        if zeroCrossingRate >= 0.18 {
            return .e
        }
        if zeroCrossingRate >= 0.08 {
            return rms >= 0.25 ? .o : .u
        }
        return rms >= 0.2 ? .a : .o
    }

    private static func zeroCrossingRate(_ samples: [Float]) -> Double {
        guard samples.count > 1 else {
            return 0
        }
        var crossings = 0
        var previous = samples[0]
        for sample in samples.dropFirst() {
            if (previous < 0 && sample >= 0) || (previous >= 0 && sample < 0) {
                crossings += 1
            }
            previous = sample
        }
        return Double(crossings) / Double(samples.count)
    }
}

/// The microphone mark for live samples or for one recorded WAV.
public enum MicUtterance {
    public static func mark(samples: [Float], sampleRate: Double, hasDevice: Bool) -> String {
        let activity = VoiceActivity(threshold: 0.02, silenceSeconds: 0.2, sampleRate: max(sampleRate, 1))
        return LiveUtterance.mark(
            hasDevice: hasDevice,
            sampleCount: samples.count,
            speech: activity.containsSpeech(samples)
        )
    }

    public static func mark(wav data: Data) -> String {
        guard let decoded = WavFile.decode(data), !decoded.samples.isEmpty else {
            return LiveUtterance.mark(hasDevice: false, sampleCount: 0, speech: false)
        }
        return mark(samples: decoded.samples, sampleRate: Double(decoded.sampleRate), hasDevice: true)
    }
}
