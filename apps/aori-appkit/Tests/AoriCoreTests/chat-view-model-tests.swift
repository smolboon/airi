import XCTest
@testable import AoriCore

final class ChatViewModelTests: XCTestCase {
    func testSendStreamsAssistantTextAndOmitsThePlaceholder() async throws {
        let client = ScriptedChatClient(events: [.delta("Hi"), .delta(" there"), .finished])
        let model = await ChatViewModel(client: client, configuration: testConfiguration())
        await model.setDraft("Hello")
        await model.send()

        let messages = await model.messages
        XCTAssertEqual(messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(messages.map(\.content), ["Hello", "Hi there"])
        let phase = await model.phase
        XCTAssertEqual(phase, .idle)

        let recorded = client.recordedMessages()
        XCTAssertEqual(recorded.first?.map(\.role), [.system, .user])
        XCTAssertEqual(recorded.first?.last?.content, "Hello")
        XCTAssertEqual(recorded.first?.first?.content, ChatPrompt.companion)
    }

    func testFailureKeepsPartialText() async throws {
        let client = PartialChatClient()
        let model = await ChatViewModel(client: client, configuration: testConfiguration())
        await model.setDraft("Hello")
        await model.send()
        let messages = await model.messages
        XCTAssertEqual(messages.last?.content, "Partial")
        let phase = await model.phase
        XCTAssertEqual(phase, .failed("The provider returned HTTP 500. down"))
    }

    func testEmptyReplyFailsAndEmptyDraftDoesNotSend() async throws {
        let client = ScriptedChatClient(events: [.finished])
        let model = await ChatViewModel(client: client, configuration: testConfiguration())
        await model.setDraft("   ")
        await model.send()
        let untouched = await model.messages
        XCTAssertTrue(untouched.isEmpty)
        XCTAssertTrue(client.recordedMessages().isEmpty)

        await model.setDraft("Hello")
        await model.send()
        let phase = await model.phase
        XCTAssertEqual(phase, .failed("The provider returned no text."))
    }

    func testTranscriptClearAndSpeechText() async {
        let model = await ChatViewModel(client: ScriptedChatClient(events: []), configuration: testConfiguration())
        await model.applyTranscript("heard you")
        let draft = await model.draft
        XCTAssertEqual(draft, "heard you")
        let spokenBefore = await model.textForSpeech()
        XCTAssertNil(spokenBefore)

        await model.clear()
        let cleared = await model.draft
        XCTAssertEqual(cleared, "")
    }

    func testGreetingDoesNotCallTheProvider() async {
        let client = ScriptedChatClient(events: [])
        let model = await ChatViewModel(client: client, configuration: testConfiguration())
        await model.greetIfNeeded()
        await model.greetIfNeeded()
        let messages = await model.messages
        XCTAssertEqual(messages.map(\.role), [.assistant])
        XCTAssertEqual(messages.first?.content, CompanionGreeting.opening(persona: .standard, memory: .empty))
        XCTAssertTrue(client.recordedMessages().isEmpty)
        let emotion = await model.presentation.emotion
        XCTAssertEqual(emotion, .happy)
    }

    func testRememberThatStoresAFactInThePrompt() async {
        let client = ScriptedChatClient(events: [.delta("I am glad to keep that."), .finished])
        let model = await ChatViewModel(client: client, configuration: testConfiguration())
        await model.setDraft("Remember that I like tea")
        await model.send()
        let notes = await model.memory.notes.map(\.text)
        XCTAssertEqual(notes, ["I like tea"])
        let recorded = client.recordedMessages()
        XCTAssertTrue(recorded.first?.first?.content.contains("I like tea") == true)
        let emotion = await model.presentation.emotion
        XCTAssertEqual(emotion, .happy)
    }
}

private func testConfiguration() -> ProviderConfiguration {
    ProviderConfiguration(
        baseURL: URL(string: "https://example.test/v1")!,
        model: "test-model",
        apiKey: "test-key",
        keySource: .explicit
    )
}

private final class ScriptedChatClient: ChatCompletionClient, @unchecked Sendable {
    private let recorded = LockedBox<[[ChatMessage]]>([])
    private let events: [ChatStreamEvent]

    init(events: [ChatStreamEvent]) {
        self.events = events
    }

    func streamChat(
        messages: [ChatMessage],
        configuration: ProviderConfiguration
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        recorded.append(messages)
        let events = events
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func recordedMessages() -> [[ChatMessage]] {
        recorded.value
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ item: Value.Element) where Value: RangeReplaceableCollection {
        lock.lock()
        defer { lock.unlock() }
        storage.append(item)
    }
}

private final class PartialChatClient: ChatCompletionClient, @unchecked Sendable {
    func streamChat(
        messages: [ChatMessage],
        configuration: ProviderConfiguration
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.delta("Partial"))
            continuation.finish(throwing: ChatProviderError.httpStatus(500, "down"))
        }
    }
}
