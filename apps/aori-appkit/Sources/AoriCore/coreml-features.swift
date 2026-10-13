import Foundation

/// Locations for the bundled MiniLM sentence model.
public enum CoreMLFeatures {
    public static func bundledModelURL() -> URL? {
        bundled(name: "aori-minilm", extension: "mlmodel")
    }

    public static func bundledVocabularyURL() -> URL? {
        bundled(name: "aori-minilm-vocab", extension: "txt")
    }

    public static func bundledReferenceURL() -> URL? {
        bundled(name: "aori-minilm-reference", extension: "json")
    }

    private static func bundled(name: String, extension ext: String) -> URL? {
        if let url = BundledFile.url(name: name, extension: ext) {
            return url
        }
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        return Bundle.module.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "Resources"
        )
    }
}
