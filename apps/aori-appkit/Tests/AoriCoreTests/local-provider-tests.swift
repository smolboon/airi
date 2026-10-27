import XCTest
@testable import AoriCore

final class LocalProviderCatalogTests: XCTestCase {
    func testCatalogOffersMlxServeAndTensorFold() {
        XCTAssertEqual(LocalProviderCatalog.options.map(\.id), ["openai", "mlx-serve", "tensorfold", "ollama"])
        XCTAssertEqual(LocalProviderCatalog.title(for: "mlx-serve"), "MLX-Serve")
        XCTAssertEqual(LocalProviderCatalog.title(for: "tensorfold"), "TensorFold")
        XCTAssertEqual(LocalProviderCatalog.title(for: "ollama"), "Ollama")
        XCTAssertEqual(LocalProviderCatalog.defaultBaseURL(for: "mlx-serve"), "http://localhost:11234/v1/")
        XCTAssertEqual(LocalProviderCatalog.defaultBaseURL(for: "tensorfold"), "http://127.0.0.1:8080/v1/")
        XCTAssertEqual(LocalProviderCatalog.defaultBaseURL(for: "ollama"), "http://localhost:11434/v1/")
    }

    func testSelectingALocalProviderFillsItsDefaultURL() {
        XCTAssertEqual(
            LocalProviderCatalog.resolvedBaseURL(provider: "mlx-serve", current: ""),
            "http://localhost:11234/v1/"
        )
        XCTAssertEqual(
            LocalProviderCatalog.resolvedBaseURL(
                provider: "tensorfold",
                current: "https://api.openai.com/v1"
            ),
            "http://127.0.0.1:8080/v1/"
        )
        XCTAssertEqual(
            LocalProviderCatalog.resolvedBaseURL(
                provider: "mlx-serve",
                current: "http://127.0.0.1:9000/v1"
            ),
            "http://127.0.0.1:9000/v1"
        )
        XCTAssertEqual(
            LocalProviderCatalog.resolvedBaseURL(provider: "ollama", current: ""),
            "http://localhost:11434/v1/"
        )
        XCTAssertEqual(
            LocalProviderCatalog.resolvedBaseURL(
                provider: "ollama",
                current: "http://localhost:11234/v1/"
            ),
            "http://localhost:11434/v1/"
        )
    }
}
