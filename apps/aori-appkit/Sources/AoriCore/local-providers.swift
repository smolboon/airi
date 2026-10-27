import Foundation

/// Local chat servers that speak the OpenAI chat API.
public enum LocalProviderCatalog {
    public struct Option: Equatable, Sendable {
        public var id: String
        public var title: String
        public var baseURL: String

        public init(id: String, title: String, baseURL: String) {
            self.id = id
            self.title = title
            self.baseURL = baseURL
        }
    }

    public static let options: [Option] = [
        Option(id: "openai", title: "OpenAI-compatible", baseURL: "https://api.openai.com/v1"),
        Option(id: "mlx-serve", title: "MLX-Serve", baseURL: "http://localhost:11234/v1/"),
        Option(id: "tensorfold", title: "TensorFold", baseURL: "http://127.0.0.1:8080/v1/"),
        Option(id: "ollama", title: "Ollama", baseURL: "http://localhost:11434/v1/"),
        Option(id: "lm-studio", title: "LM Studio", baseURL: "http://localhost:1234/v1/"),
    ]

    public static func title(for id: String) -> String {
        options.first { $0.id == id }?.title ?? id
    }

    public static func defaultBaseURL(for id: String) -> String {
        options.first { $0.id == id }?.baseURL ?? options[0].baseURL
    }

    /// Keeps a custom URL. An empty URL or another catalog default takes the selected default.
    public static func resolvedBaseURL(provider: String, current: String) -> String {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = defaultBaseURL(for: provider)
        if trimmed.isEmpty {
            return selected
        }
        let defaults = Set(options.map(\.baseURL))
        if defaults.contains(trimmed), trimmed != selected {
            return selected
        }
        return trimmed
    }
}
