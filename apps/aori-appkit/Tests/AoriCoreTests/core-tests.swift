import XCTest
@testable import AoriCore

final class SSEDecoderTests: XCTestCase {
    func testSplitsEventsAcrossChunks() {
        var decoder = SSEDecoder()
        let first = decoder.feed("data: one\n")
        XCTAssertTrue(first.isEmpty)
        let second = decoder.feed("\ndata: two\n\n")
        XCTAssertEqual(second.map(\.data), ["one", "two"])
    }

    func testParsesCRLFCommentsAndEventName() {
        var decoder = SSEDecoder()
        let events = decoder.feed(": keep-alive\r\nevent: delta\r\ndata: hello\r\ndata: world\r\n\r\n")
        XCTAssertEqual(events, [SSEEvent(event: "delta", data: "hello\nworld")])
    }

    func testFinishReadsTrailingEvent() {
        var decoder = SSEDecoder()
        XCTAssertTrue(decoder.feed("data: tail").isEmpty)
        XCTAssertEqual(decoder.finish().map(\.data), ["tail"])
    }
}

final class UTF8StreamDecoderTests: XCTestCase {
    func testKeepsSplitEmojiUntilComplete() {
        var decoder = UTF8StreamDecoder()
        let emoji = Data("😀".utf8)
        XCTAssertEqual(emoji.count, 4)
        XCTAssertEqual(decoder.feed(emoji.prefix(2)), "")
        XCTAssertEqual(decoder.feed(emoji.suffix(2)), "😀")
        XCTAssertEqual(decoder.finish(), "")
    }
}

final class SandboxReportTests: XCTestCase {
    func testReadsTheContainerId() {
        XCTAssertEqual(SandboxReport.line(environment: [:]), "aori_sandbox=off")
        XCTAssertEqual(
            SandboxReport.line(environment: ["APP_SANDBOX_CONTAINER_ID": "ai.moeru.aori.appkit"]),
            "aori_sandbox=on"
        )
        XCTAssertEqual(SandboxReport.line(environment: ["APP_SANDBOX_CONTAINER_ID": "  "]), "aori_sandbox=off")
    }
}

final class SecretRedactionTests: XCTestCase {
    func testRedactsAndClips() {
        XCTAssertEqual(SecretRedaction.redact("token sk-test leaked", secret: "sk-test"), "token [redacted] leaked")
        XCTAssertEqual(SecretRedaction.clip(String(repeating: "a", count: 500), limit: 20).count, 20)
        XCTAssertFalse(ProviderConfiguration(
            baseURL: URL(string: "https://api.openai.com/v1")!,
            model: "gpt-4o-mini",
            apiKey: "sk-secret",
            keySource: .explicit
        ).redactedDescription.contains("sk-secret"))
    }
}

final class ProviderConfigurationTests: XCTestCase {
    func testExplicitKeyBeatsEnvironmentAndKeychain() throws {
        let store = InMemorySecretStore()
        try store.write(account: AoriSecrets.openAIAPIKeyAccount, secret: "from-keychain")
        let resolver = ProviderConfigurationResolver(
            environment: [
                "AORI_OPENAI_API_KEY": "from-aori",
                "OPENAI_API_KEY": "from-openai",
                "AORI_OPENAI_BASE_URL": "http://127.0.0.1:11434/v1",
                "OPENAI_MODEL": "ignored-model",
            ],
            secretStore: store,
            storedBaseURL: "https://stored.example/v1",
            storedModel: "stored-model"
        )
        let configuration = try resolver.resolve(explicit: ExplicitProviderInput(model: "explicit-model", apiKey: "explicit-key"))
        XCTAssertEqual(configuration.apiKey, "explicit-key")
        XCTAssertEqual(configuration.keySource, .explicit)
        XCTAssertEqual(configuration.model, "explicit-model")
        XCTAssertEqual(configuration.baseURL.absoluteString, "http://127.0.0.1:11434/v1")
    }

    func testAoriEnvironmentBeatsOpenAIAndKeychain() throws {
        let store = InMemorySecretStore()
        try store.write(account: AoriSecrets.openAIAPIKeyAccount, secret: "from-keychain")
        let resolver = ProviderConfigurationResolver(
            environment: [
                "AORI_OPENAI_API_KEY": " from-aori ",
                "OPENAI_API_KEY": "from-openai",
                "OPENAI_BASE_URL": "https://openai.example/v1/",
                "OPENAI_MODEL": "openai-model",
            ],
            secretStore: store
        )
        let configuration = try resolver.resolve()
        XCTAssertEqual(configuration.apiKey, "from-aori")
        XCTAssertEqual(configuration.keySource, .aoriEnvironment)
        XCTAssertEqual(configuration.model, "openai-model")
        XCTAssertEqual(configuration.chatCompletionsURL.absoluteString, "https://openai.example/v1/chat/completions")
    }

    func testKeychainIsUsedWhenEnvironmentIsBlank() throws {
        let store = InMemorySecretStore()
        try store.write(account: AoriSecrets.openAIAPIKeyAccount, secret: "from-keychain")
        let resolver = ProviderConfigurationResolver(
            environment: ["AORI_OPENAI_API_KEY": "  ", "OPENAI_API_KEY": ""],
            secretStore: store,
            storedModel: "stored-model"
        )
        let configuration = try resolver.resolve()
        XCTAssertEqual(configuration.apiKey, "from-keychain")
        XCTAssertEqual(configuration.keySource, .keychain)
        XCTAssertEqual(configuration.model, "stored-model")
        XCTAssertEqual(configuration.baseURL.absoluteString, "https://api.openai.com/v1")
    }

    func testMissingKeyAndInvalidURL() throws {
        let resolver = ProviderConfigurationResolver(environment: [:], secretStore: InMemorySecretStore())
        let missing = try resolver.resolve()
        XCTAssertEqual(missing.keySource, .missing)
        XCTAssertEqual(missing.apiKey, "")

        let invalid = ProviderConfigurationResolver(
            environment: ["AORI_OPENAI_BASE_URL": "not a url"],
            secretStore: InMemorySecretStore()
        )
        XCTAssertThrowsError(try invalid.resolve()) { error in
            XCTAssertEqual(error as? ProviderConfigurationError, .invalidBaseURL("not a url"))
        }
    }

    func testSecretStoreFailureDoesNotIncludeAPlantedKey() {
        let resolver = ProviderConfigurationResolver(environment: [:], secretStore: ThrowingSecretStore())
        XCTAssertThrowsError(try resolver.resolve()) { error in
            let text = String(describing: error)
            XCTAssertTrue(text.contains("boom"))
            XCTAssertFalse(text.contains("sk-planted"))
        }
    }

    func testTrailingSlashStillBuildsChatURL() {
        let configuration = ProviderConfiguration(
            baseURL: URL(string: "https://api.openai.com/v1/")!,
            model: "gpt-4o-mini",
            apiKey: "test-key",
            keySource: .explicit
        )
        XCTAssertEqual(configuration.chatCompletionsURL.absoluteString, "https://api.openai.com/v1/chat/completions")
    }
}

private final class ThrowingSecretStore: SecretStore, @unchecked Sendable {
    func read(account: String) throws -> String? {
        throw ThrowingSecretError.boom
    }

    func write(account: String, secret: String) throws {}

    func delete(account: String) throws {}
}

private enum ThrowingSecretError: Error, CustomStringConvertible {
    case boom

    var description: String {
        "boom"
    }
}
