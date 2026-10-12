import Foundation

public enum CredentialSource: String, Equatable, Sendable {
    case explicit
    case aoriEnvironment
    case openaiEnvironment
    case keychain
    case missing
}

public struct ProviderConfiguration: Equatable, Sendable {
    public var baseURL: URL
    public var model: String
    public var apiKey: String
    public var keySource: CredentialSource

    public init(baseURL: URL, model: String, apiKey: String, keySource: CredentialSource) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.keySource = keySource
    }

    public var chatCompletionsURL: URL {
        baseURL.appendingPathComponent("chat").appendingPathComponent("completions")
    }

    /// Describes the configuration without the API key.
    public var redactedDescription: String {
        "model=\(model) baseURL=\(baseURL.absoluteString) keySource=\(keySource.rawValue)"
    }
}

public struct ExplicitProviderInput: Equatable, Sendable {
    public var baseURL: String?
    public var model: String?
    public var apiKey: String?

    public init(baseURL: String? = nil, model: String? = nil, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
    }
}

public enum ProviderConfigurationError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidBaseURL(String)
    case secretStoreFailed(String)

    public var description: String {
        switch self {
        case .invalidBaseURL(let value):
            return "The base URL is not valid: \(value)"
        case .secretStoreFailed(let message):
            return "The secret store failed. \(message)"
        }
    }
}

public struct ProviderConfigurationResolver: Sendable {
    public var environment: [String: String]
    public var secretStore: any SecretStore
    public var storedBaseURL: String?
    public var storedModel: String?
    public var defaultBaseURL: String
    public var defaultModel: String

    public init(
        environment: [String: String],
        secretStore: any SecretStore,
        storedBaseURL: String? = nil,
        storedModel: String? = nil,
        defaultBaseURL: String = "https://api.openai.com/v1",
        defaultModel: String = "gpt-4o-mini"
    ) {
        self.environment = environment
        self.secretStore = secretStore
        self.storedBaseURL = storedBaseURL
        self.storedModel = storedModel
        self.defaultBaseURL = defaultBaseURL
        self.defaultModel = defaultModel
    }

    public func resolve(explicit: ExplicitProviderInput = ExplicitProviderInput()) throws -> ProviderConfiguration {
        let baseURLText = firstText(
            explicit.baseURL,
            environment["AORI_OPENAI_BASE_URL"],
            environment["OPENAI_BASE_URL"],
            storedBaseURL,
            defaultBaseURL
        )
        guard let baseURL = URL(string: baseURLText), baseURL.scheme == "http" || baseURL.scheme == "https" else {
            throw ProviderConfigurationError.invalidBaseURL(baseURLText)
        }

        let model = firstText(
            explicit.model,
            environment["AORI_OPENAI_MODEL"],
            environment["OPENAI_MODEL"],
            storedModel,
            defaultModel
        )

        let key = try resolveKey(explicit: explicit)
        return ProviderConfiguration(
            baseURL: baseURL,
            model: model,
            apiKey: key.value,
            keySource: key.source
        )
    }

    private func resolveKey(explicit: ExplicitProviderInput) throws -> (value: String, source: CredentialSource) {
        if let explicitKey = nonBlank(explicit.apiKey) {
            return (explicitKey, .explicit)
        }
        if let aoriKey = nonBlank(environment["AORI_OPENAI_API_KEY"]) {
            return (aoriKey, .aoriEnvironment)
        }
        if let openAIKey = nonBlank(environment["OPENAI_API_KEY"]) {
            return (openAIKey, .openaiEnvironment)
        }
        let stored: String?
        do {
            stored = try secretStore.read(account: AoriSecrets.openAIAPIKeyAccount)
        } catch {
            throw ProviderConfigurationError.secretStoreFailed(String(describing: error))
        }
        if let storedKey = nonBlank(stored) {
            return (storedKey, .keychain)
        }
        return ("", .missing)
    }

    private func firstText(_ values: String?...) -> String {
        for value in values {
            if let text = nonBlank(value) {
                return text
            }
        }
        return ""
    }

    private func nonBlank(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
