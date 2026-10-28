import XCTest
@testable import AoriCore

final class LocalLoopbackTests: XCTestCase {
    func testOnlyLocalhostAndTheLoopbackAddressPass() {
        XCTAssertTrue(LocalLoopback.allows(URL(string: "http://localhost:11434/v1/")!))
        XCTAssertTrue(LocalLoopback.allows(URL(string: "http://127.0.0.1:1234/v1/")!))
        XCTAssertTrue(LocalLoopback.allows(URL(string: "https://localhost/v1")!))
        XCTAssertFalse(LocalLoopback.allows(URL(string: "https://api.openai.com/v1")!))
        XCTAssertFalse(LocalLoopback.allows(URL(string: "http://localhost.example/v1")!))
        XCTAssertFalse(LocalLoopback.allows(URL(string: "http://203.0.113.10:11434/v1")!))
        XCTAssertFalse(LocalLoopback.allows(URL(string: "file:///tmp/chat")!))
    }

    func testEmptyKeyUsesTheServerOnlyOnLoopback() {
        let remote = ProviderConfiguration(
            baseURL: URL(string: "https://api.openai.com/v1")!,
            model: "gpt-4o-mini",
            apiKey: "",
            keySource: .missing
        )
        let ollama = ProviderConfiguration(
            baseURL: URL(string: "http://localhost:11434/v1/")!,
            model: "gpt-4o-mini",
            apiKey: "",
            keySource: .missing
        )
        let namedLocal = ProviderConfiguration(
            baseURL: URL(string: "http://127.0.0.1:11434/v1/")!,
            model: "local",
            apiKey: "",
            keySource: .missing
        )
        XCTAssertTrue(ChatRoute.usesDeviceTemplate(remote))
        XCTAssertFalse(ChatRoute.usesDeviceTemplate(ollama))
        XCTAssertTrue(ChatRoute.usesDeviceTemplate(namedLocal))
        XCTAssertTrue(ChatRoute.missingKeyStatus(baseURL: remote.baseURL).contains("AORI_OPENAI_API_KEY"))
        XCTAssertTrue(ChatRoute.missingKeyStatus(baseURL: ollama.baseURL).contains("does not need one"))
        XCTAssertEqual(ChatRoute.keyPlaceholder(baseURL: ollama.baseURL, keyIsEmpty: true), "API key. Optional on this machine.")
        XCTAssertEqual(ChatRoute.keyPlaceholder(baseURL: remote.baseURL, keyIsEmpty: true), "API key")
        XCTAssertFalse(ChatRoute.missingKeyStatus(baseURL: ollama.baseURL).lowercased().contains("airi"))
    }
}
