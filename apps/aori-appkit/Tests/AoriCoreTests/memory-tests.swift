import XCTest
@testable import AoriCore

final class EmbeddingMemoryTests: XCTestCase {
    func testCosineRecallPrefersTheSharedWord() throws {
        XCTAssertNotNil(CoreMLFeatures.bundledModelURL())
        let tokens = CoreMLFeatures.tokens("I like tea")
        XCTAssertEqual(tokens.count, CoreMLFeatures.count)
        let tea = LocalEmbedding.embed("I like tea")
        let query = LocalEmbedding.embed("tea please")
        let cat = LocalEmbedding.embed("The cat is orange")
        XCTAssertGreaterThan(CosineSimilarity.score(query.values, tea.values), CosineSimilarity.score(query.values, cat.values))
        XCTAssertGreaterThan(CosineSimilarity.score(query.values, tea.values), MemoryRecall.minimumScore)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("aori-memory-\(UUID().uuidString).sqlite")
        let store = try EmbeddingMemoryStore(fileURL: url)
        XCTAssertTrue(store.insert(text: "I like tea", vector: tea.values, now: Date(timeIntervalSince1970: 1)))
        XCTAssertTrue(store.insert(text: "The cat is orange", vector: cat.values, now: Date(timeIntervalSince1970: 2)))
        XCTAssertFalse(store.insert(text: " i like tea ", vector: tea.values, now: Date(timeIntervalSince1970: 3)))
        XCTAssertFalse(store.insert(text: "short", vector: [1], now: Date()))
        let hits = store.recall(query: query.values, limit: 1)
        XCTAssertEqual(hits.map(\.text), ["I like tea"])
        XCTAssertEqual(store.list().count, 2)
        XCTAssertTrue(store.delete(id: store.list()[0].id))
        XCTAssertEqual(store.list().map(\.text), ["The cat is orange"])

        let reopened = try EmbeddingMemoryStore(fileURL: url)
        XCTAssertEqual(reopened.list().map(\.text), ["The cat is orange"])
        let prompt = MemoryRecall.prompt(lines: hits.map(\.text))
        XCTAssertTrue(prompt.contains("I like tea"))
        XCTAssertEqual(MemoryRecall.prompt(lines: []), "")
    }

    func testChatInjectsARecalledMemory() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("aori-memory-\(UUID().uuidString).sqlite")
        let store = try EmbeddingMemoryStore(fileURL: url)
        let client = RecordingChatClient()
        let model = await ChatViewModel(
            client: client,
            configuration: ProviderConfiguration(
                baseURL: URL(string: "https://example.test/v1")!,
                model: "local",
                apiKey: "",
                keySource: .missing
            ),
            embeddingMemory: store,
            textEmbedding: LocalTextEmbedding()
        )
        await model.setDraft("remember that I like tea")
        await model.send()
        await model.setDraft("tea please")
        await model.send()
        let system = try XCTUnwrap(client.recordedMessages().last?.first)
        XCTAssertEqual(system.role, .system)
        XCTAssertTrue(system.content.contains("I like tea"))
        let summary = await model.recalledSummary
        XCTAssertEqual(summary, "I like tea")
        XCTAssertEqual(store.list().map(\.text), ["I like tea"])
    }
}

final class VisionTickerPolicyTests: XCTestCase {
    func testTickerIsOptInAndRateLimited() {
        let off = VisionTickerPolicy.resolve(environment: [:])
        XCTAssertFalse(off.enabled)
        XCTAssertFalse(off.allows(tick: 1))

        let fast = VisionTickerPolicy.resolve(environment: [
            "AORI_VISION_TICKER": "1",
            "AORI_VISION_INTERVAL_MS": "0",
            "AORI_VISION_MAX_TICKS": "2",
        ])
        XCTAssertTrue(fast.enabled)
        XCTAssertEqual(fast.intervalMilliseconds, VisionTickerPolicy.minimumMilliseconds)
        XCTAssertTrue(fast.allows(tick: 1))
        XCTAssertTrue(fast.allows(tick: 2))
        XCTAssertFalse(fast.allows(tick: 3))

        let huge = VisionTickerPolicy.resolve(environment: [
            "AORI_VISION_TICKER": "1",
            "AORI_VISION_MAX_TICKS": "100",
        ])
        XCTAssertEqual(huge.maximumTicks, VisionTickerPolicy.maximumAllowedTicks)
    }
}

private final class RecordingChatClient: ChatCompletionClient, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [[ChatMessage]] = []

    func streamChat(
        messages: [ChatMessage],
        configuration _: ProviderConfiguration
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        record(messages)
        return AsyncThrowingStream { continuation in
            continuation.yield(.delta("ok"))
            continuation.yield(.finished)
            continuation.finish()
        }
    }

    func record(_ messages: [ChatMessage]) {
        lock.lock()
        recorded.append(messages)
        lock.unlock()
    }

    func recordedMessages() -> [[ChatMessage]] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }
}
