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
    public private(set) var persona: CompanionPersona
    public private(set) var memory: UserMemory
    public var onChange: (@MainActor () -> Void)?
    public var onProfileChange: (@MainActor () -> Void)?

    private let client: any ChatCompletionClient
    private var showsModelTitle = false

    public init(
        client: any ChatCompletionClient,
        configuration: ProviderConfiguration,
        persona: CompanionPersona = .standard,
        memory: UserMemory = .empty
    ) {
        self.client = client
        self.configuration = configuration
        self.persona = persona
        self.memory = memory
        presentation.title = persona.name
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
        presentation.emotion = .neutral
        publish()
    }

    public func updatePersona(_ persona: CompanionPersona) {
        let name = persona.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.persona = CompanionPersona(
            name: name.isEmpty ? CompanionPersona.standard.name : name,
            personality: persona.personality.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if !showsModelTitle {
            presentation.title = self.persona.name
        }
        onProfileChange?()
        publish()
    }

    /// Adds a local greeting when the transcript is empty. This does not call the provider.
    public func greetIfNeeded() {
        guard messages.isEmpty else {
            return
        }
        let text = CompanionGreeting.opening(persona: persona, memory: memory)
        messages.append(ChatMessage(role: .assistant, content: text))
        presentation.emotion = .happy
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
        showsModelTitle = true
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
        if let note = MemoryCapture.note(from: text), memory.remember(note) {
            onProfileChange?()
        }
        messages.append(ChatMessage(role: .user, content: text))
        var assistant = ChatMessage(role: .assistant, content: "")
        messages.append(assistant)
        phase = .streaming
        statusText = "Aori is writing."
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
                    presentation.emotion = CompanionEmotion.infer(from: assistant.content)
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
        let systemPrompt = CompanionPrompt.system(persona: persona, memory: memory)
        var items = [ChatMessage(role: .system, content: systemPrompt)]
        let history = messages.dropLast()
        items.append(contentsOf: history)
        return items
    }

    private func publish() {
        onChange?()
    }
}
