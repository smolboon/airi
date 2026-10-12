import Foundation

public enum WavFile {
    /// Writes mono 16-bit PCM. The header is a RIFF WAVE file.
    public static func encode(samples: [Float], sampleRate: Int) -> Data {
        let rate = max(sampleRate, 1)
        var pcm = Data()
        pcm.reserveCapacity(samples.count * 2)
        for sample in samples {
            let clamped = min(1, max(-1, sample))
            var value = Int16((clamped * Float(Int16.max)).rounded()).littleEndian
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }
        let dataSize = pcm.count
        var data = Data()
        data.append(contentsOf: [UInt8]("RIFF".utf8))
        appendU32(UInt32(36 + dataSize), to: &data)
        data.append(contentsOf: [UInt8]("WAVE".utf8))
        data.append(contentsOf: [UInt8]("fmt ".utf8))
        appendU32(16, to: &data)
        appendU16(1, to: &data)
        appendU16(1, to: &data)
        appendU32(UInt32(rate), to: &data)
        appendU32(UInt32(rate * 2), to: &data)
        appendU16(2, to: &data)
        appendU16(16, to: &data)
        data.append(contentsOf: [UInt8]("data".utf8))
        appendU32(UInt32(dataSize), to: &data)
        data.append(pcm)
        return data
    }

    public static func rms(samples: [Float]) -> Double {
        guard !samples.isEmpty else {
            return 0
        }
        var sum = 0.0
        for sample in samples {
            let value = Double(sample)
            sum += value * value
        }
        return (sum / Double(samples.count)).squareRoot()
    }

    private static func appendU16(_ value: UInt16, to data: inout Data) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    private static func appendU32(_ value: UInt32, to data: inout Data) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
}
