import XCTest
@testable import AoriCore

final class AudioVisemeTests: XCTestCase {
    func testFramesMapAmplitudeAndZeroCrossings() {
        let rate = 16_000.0
        let count = 320
        let silence = [Float](repeating: 0, count: count)
        let open = AudioViseme.tone(frequency: 200, amplitude: 0.5, sampleRate: rate, count: count)
        let closure = [Float](repeating: 0.04, count: count)
        let front = AudioViseme.tone(frequency: 2200, amplitude: 0.4, sampleRate: rate, count: count)
        let round = AudioViseme.tone(frequency: 900, amplitude: 0.4, sampleRate: rate, count: count)
        let samples = silence + open + closure + front + round
        let presets = AudioViseme.presets(samples: samples, sampleRate: rate)
        XCTAssertEqual(presets, [.sil, .a, .pp, .e, .o])
        XCTAssertEqual(
            AudioViseme.phonemes(samples: samples, sampleRate: rate),
            ["SIL", "AA", "P", "EH", "OW"]
        )
        XCTAssertFalse(AudioViseme.phonemes(samples: samples, sampleRate: rate).contains("HH"))
    }

    func testRecordedWavMarksSpeechAndSilenceStaysQuiet() {
        let rate = 16_000.0
        let speech = AudioViseme.tone(frequency: 200, amplitude: 0.3, sampleRate: rate, count: 1600)
        let loud = WavFile.encode(samples: speech, sampleRate: Int(rate))
        XCTAssertEqual(MicUtterance.mark(wav: loud), "speech")
        let quiet = WavFile.encode(samples: [Float](repeating: 0, count: 1600), sampleRate: Int(rate))
        XCTAssertEqual(MicUtterance.mark(wav: quiet), "silence")
        XCTAssertEqual(MicUtterance.mark(wav: Data()), "no-device")
    }
}
