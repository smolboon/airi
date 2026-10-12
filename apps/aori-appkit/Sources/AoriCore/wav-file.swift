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

    /// Reads mono 16-bit PCM from a RIFF WAVE file.
    public static func decode(_ data: Data) -> (samples: [Float], sampleRate: Int)? {
        guard data.count >= 44 else {
            return nil
        }
        guard String(decoding: data.prefix(4), as: UTF8.self) == "RIFF" else {
            return nil
        }
        guard String(decoding: data.dropFirst(8).prefix(4), as: UTF8.self) == "WAVE" else {
            return nil
        }
        var offset = 12
        var sampleRate = 0
        var channels = 0
        var bits = 0
        var pcm: Data?
        while offset + 8 <= data.count {
            let tag = String(decoding: data.subdata(in: offset..<(offset + 4)), as: UTF8.self)
            let size = Int(readU32(data, offset + 4))
            let start = offset + 8
            let end = min(data.count, start + size)
            if tag == "fmt ", end >= start + 16 {
                channels = Int(readU16(data, start + 2))
                sampleRate = Int(readU32(data, start + 4))
                bits = Int(readU16(data, start + 14))
            }
            if tag == "data" {
                pcm = data.subdata(in: start..<end)
            }
            offset = start + size + (size % 2)
        }
        guard bits == 16, channels >= 1, sampleRate > 0, let pcm, pcm.count >= 2 else {
            return nil
        }
        let frameBytes = channels * 2
        let frames = pcm.count / frameBytes
        var samples: [Float] = []
        samples.reserveCapacity(frames)
        for frame in 0..<frames {
            var mixed = 0.0
            for channel in 0..<channels {
                let index = frame * frameBytes + channel * 2
                let unit = Int16(bitPattern: readU16(pcm, index))
                mixed += Double(unit) / Double(Int16.max)
            }
            samples.append(Float(mixed / Double(channels)))
        }
        return (samples, sampleRate)
    }

    private static func readU16(_ data: Data, _ offset: Int) -> UInt16 {
        guard offset + 1 < data.count else {
            return 0
        }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readU32(_ data: Data, _ offset: Int) -> UInt32 {
        guard offset + 3 < data.count else {
            return 0
        }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
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
