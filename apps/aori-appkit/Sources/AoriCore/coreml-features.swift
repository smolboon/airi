import Foundation

/// Character features for the bundled linear Core ML network.
/// The network is not a trained sentence transformer.
public enum CoreMLFeatures {
    public static let count = 64

    public static func tokens(_ text: String) -> [Float] {
        var buckets = [Float](repeating: 0, count: count)
        let letters = text.lowercased().filter { character in
            guard let ascii = character.asciiValue else {
                return false
            }
            return ascii >= 97 && ascii <= 122
        }
        var previous: UInt8?
        for byte in letters.utf8 {
            buckets[Int(byte - 97)] += 1
            if let previous {
                buckets[26 + Int((previous &+ byte) % 38)] += 1
            }
            previous = byte
        }
        var sum: Float = 0
        for value in buckets {
            sum += value * value
        }
        let norm = sqrt(sum)
        guard norm > 0 else {
            return buckets
        }
        return buckets.map { $0 / norm }
    }

    public static func bundledModelURL() -> URL? {
        if let url = BundledFile.url(name: "aori-embed", extension: "mlmodel") {
            return url
        }
        if let url = Bundle.module.url(forResource: "aori-embed", withExtension: "mlmodel") {
            return url
        }
        return Bundle.module.url(
            forResource: "aori-embed",
            withExtension: "mlmodel",
            subdirectory: "Resources"
        )
    }
}
