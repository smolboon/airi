import Foundation

public enum ChatStreamEvent: Equatable, Sendable {
    case delta(String)
    case finished
}

public protocol ChatCompletionClient: Sendable {
    func streamChat(
        messages: [ChatMessage],
        configuration: ProviderConfiguration
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error>
}

public enum ChatPhase: Equatable, Sendable {
    case idle
    case streaming
    case failed(String)
}

@MainActor
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage] = []
    public private(set) var draft = ""
    public private(set) var phase: ChatPhase = .idle
    public private(set) var statusText = ""
    public private(set) var presentation: CharacterPresentation = .placeholder
    public private(set) var isSpeaking = false
    public private(set) var configuration: ProviderConfiguration
    public var onChange: (@MainActor () -> Void)?

    private let client: any ChatCompletionClient
    private let systemPrompt: String

    public init(
        client: any ChatCompletionClient,
        configuration: ProviderConfiguration,
        systemPrompt: String = ChatPrompt.companion
    ) {
        self.client = client
        self.configuration = configuration
        self.systemPrompt = systemPrompt
    }

    public func setDraft(_ draft: String) {
        self.draft = draft
        publish()
    }

    public func setStatus(_ text: String) {
        statusText = text
        publish()
    }

    public func updateConfiguration(_ configuration: ProviderConfiguration) {
        self.configuration = configuration
        publish()
    }

    public func clear() {
        messages = []
        draft = ""
        phase = .idle
        statusText = ""
        isSpeaking = false
        publish()
    }

    public func applyTranscript(_ text: String) {
        draft = text
        publish()
    }

    public func textForSpeech() -> String? {
        let text = messages.last(where: { $0.role == .assistant })?.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    public func setSpeaking(_ speaking: Bool) {
        isSpeaking = speaking
        publish()
    }

    public func apply(vrm document: VRMDocument) {
        presentation = presentation.applying(document)
        publish()
    }

    public func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        guard phase != .streaming else {
            return
        }

        draft = ""
        messages.append(ChatMessage(role: .user, content: text))
        var assistant = ChatMessage(role: .assistant, content: "")
        messages.append(assistant)
        phase = .streaming
        statusText = "AIRI is writing."
        publish()

        do {
            let stream = try await client.streamChat(
                messages: requestMessages(),
                configuration: configuration
            )
            for try await event in stream {
                if Task.isCancelled {
                    break
                }
                switch event {
                case .delta(let piece):
                    assistant.content += piece
                    messages[messages.count - 1] = assistant
                    publish()
                case .finished:
                    break
                }
            }
            if assistant.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                phase = .failed("The provider returned no text.")
                statusText = "The provider returned no text."
            } else {
                phase = .idle
                statusText = ""
            }
            publish()
        } catch {
            phase = .failed(String(describing: error))
            statusText = String(describing: error)
            publish()
        }
    }

    private func requestMessages() -> [ChatMessage] {
        var items = [ChatMessage(role: .system, content: systemPrompt)]
        let history = messages.dropLast()
        items.append(contentsOf: history)
        return items
    }

    private func publish() {
        onChange?()
    }
}
