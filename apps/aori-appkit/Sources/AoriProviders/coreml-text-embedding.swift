import AoriCore
import Foundation
#if canImport(CoreML)
import CoreML
#endif

public enum CoreMLTextEmbedding {
    public static func embed(text: String, modelURL: URL?) -> EmbeddingVector? {
        #if canImport(CoreML)
        guard let modelURL else {
            return nil
        }
        do {
            let compiled = try MLModel.compileModel(at: modelURL)
            let model = try MLModel(contentsOf: compiled)
            let tokens = CoreMLFeatures.tokens(text)
            let array = try MLMultiArray(shape: [NSNumber(value: CoreMLFeatures.count)], dataType: .double)
            for (index, value) in tokens.enumerated() {
                array[index] = NSNumber(value: Double(value))
            }
            let input = try MLDictionaryFeatureProvider(dictionary: ["tokens": array])
            let output = try model.prediction(from: input)
            guard let values = output.featureValue(for: "embedding")?.multiArrayValue else {
                return nil
            }
            var floats: [Float] = []
            floats.reserveCapacity(EmbeddingVector.dimensions)
            for index in 0..<EmbeddingVector.dimensions {
                floats.append(values[index].floatValue)
            }
            return EmbeddingVector(values: floats)
        } catch {
            return nil
        }
        #else
        _ = text
        _ = modelURL
        return nil
        #endif
    }
}
