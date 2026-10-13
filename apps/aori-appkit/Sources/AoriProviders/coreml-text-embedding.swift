import AoriCore
import Foundation
#if canImport(CoreML)
import CoreML
#endif

public enum CoreMLTextEmbedding {
    public static func embed(text: String, modelURL: URL?, vocabularyURL: URL?) -> EmbeddingVector? {
        #if canImport(CoreML)
        guard let modelURL, let vocabularyURL else {
            return nil
        }
        let vocabulary = WordPieceTokenizer.vocabulary(at: vocabularyURL)
        guard !vocabulary.isEmpty else {
            return nil
        }
        let encoded = WordPieceTokenizer.encode(text, vocabulary: vocabulary)
        do {
            let compiled = try MLModel.compileModel(at: modelURL)
            let model = try MLModel(contentsOf: compiled)
            let ids = try MLMultiArray(shape: [1, NSNumber(value: WordPieceTokenizer.sequenceLength)], dataType: .float32)
            let mask = try MLMultiArray(shape: [1, NSNumber(value: WordPieceTokenizer.sequenceLength)], dataType: .float32)
            for index in 0..<WordPieceTokenizer.sequenceLength {
                ids[index] = NSNumber(value: encoded.ids[index])
                mask[index] = NSNumber(value: encoded.mask[index])
            }
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": MLFeatureValue(multiArray: ids),
                "attention_mask": MLFeatureValue(multiArray: mask),
            ])
            let output = try model.prediction(from: input)
            guard let values = output.featureValue(for: "embedding")?.multiArrayValue else {
                return nil
            }
            guard values.count == EmbeddingVector.sentenceDimensions else {
                return nil
            }
            var floats: [Float] = []
            floats.reserveCapacity(values.count)
            for index in 0..<values.count {
                floats.append(values[index].floatValue)
            }
            return EmbeddingVector(values: floats)
        } catch {
            return nil
        }
        #else
        _ = text
        _ = modelURL
        _ = vocabularyURL
        return nil
        #endif
    }
}
