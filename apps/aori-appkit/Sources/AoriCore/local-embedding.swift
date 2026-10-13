import Foundation

public struct EmbeddingVector: Equatable, Sendable {
    public static let dimensions = 32

    public var values: [Float]

    public init(values: [Float]) {
        if values.count == Self.dimensions {
            self.values = values
            return
        }
        var padded = Array(values.prefix(Self.dimensions))
        if padded.count < Self.dimensions {
            padded.append(contentsOf: repeatElement(0, count: Self.dimensions - padded.count))
        }
        self.values = padded
    }
}

public enum EmbeddingSource: String, Equatable, Sendable {
    case endpoint
    case local
}

public struct EmbeddingOutcome: Equatable, Sendable {
    public var vector: EmbeddingVector
    public var source: EmbeddingSource

    public init(vector: EmbeddingVector, source: EmbeddingSource) {
        self.vector = vector
        self.source = source
    }
}

public protocol TextEmbedding: Sendable {
    func embed(_ text: String, configuration: ProviderConfiguration) async -> EmbeddingOutcome
}

/// Hashing embedder. This is not a neural sentence model.
public enum LocalEmbedding {
    public static func embed(_ text: String) -> EmbeddingVector {
        var buckets = [Float](repeating: 0, count: EmbeddingVector.dimensions)
        for raw in text.lowercased().split(whereSeparator: \.isWhitespace) {
            let cleaned = raw.filter { character in
                guard let ascii = character.asciiValue else {
                    return false
                }
                return ascii >= 97 && ascii <= 122
            }
            guard !cleaned.isEmpty else {
                continue
            }
            var hash: UInt32 = 2_166_136_261
            for byte in cleaned.utf8 {
                hash ^= UInt32(byte)
                hash = hash &* 16_777_619
            }
            let index = Int(hash % UInt32(EmbeddingVector.dimensions))
            buckets[index] += 1
        }
        var sum: Float = 0
        for value in buckets {
            sum += value * value
        }
        let norm = sqrt(sum)
        guard norm > 0 else {
            return EmbeddingVector(values: buckets)
        }
        return EmbeddingVector(values: buckets.map { $0 / norm })
    }
}

public struct LocalTextEmbedding: TextEmbedding {
    public init() {}

    public func embed(_ text: String, configuration _: ProviderConfiguration) async -> EmbeddingOutcome {
        EmbeddingOutcome(vector: LocalEmbedding.embed(text), source: .local)
    }
}

public enum CosineSimilarity {
    public static func score(_ left: [Float], _ right: [Float]) -> Float {
        let count = min(left.count, right.count)
        guard count > 0 else {
            return 0
        }
        var dot: Float = 0
        var leftNorm: Float = 0
        var rightNorm: Float = 0
        for index in 0..<count {
            dot += left[index] * right[index]
            leftNorm += left[index] * left[index]
            rightNorm += right[index] * right[index]
        }
        let denom = sqrt(leftNorm) * sqrt(rightNorm)
        guard denom > 0 else {
            return 0
        }
        return dot / denom
    }
}

public enum MemoryRecall {
    public static let minimumScore: Float = 0.2

    public static func prompt(lines: [String]) -> String {
        let kept = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !kept.isEmpty else {
            return ""
        }
        let body = kept.map { "- \($0)" }.joined(separator: "\n")
        return "Related memories:\n\(body)"
    }
}
