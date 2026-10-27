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
    public private(set) var recalledSummary = "none"
    public private(set) var vrmScene: VRMScene?
    public private(set) var modelBytes: Data?
    public private(set) var mouthLevel: Double = 0
    public private(set) var viseme = "a"
    private var peakMouth = 0.0
    private var lastOpenViseme = "a"
    public var onChange: (@MainActor () -> Void)?
    public var onProfileChange: (@MainActor () -> Void)?
    public var onTranscriptChange: (@MainActor () -> Void)?

    private let client: any ChatCompletionClient
    private let embeddingMemory: EmbeddingMemoryStore?
    private let textEmbedding: (any TextEmbedding)?
    private var showsModelTitle = false
    private var recalledLines: [String] = []

    public init(
        client: any ChatCompletionClient,
        configuration: ProviderConfiguration,
        persona: CompanionPersona = .standard,
        memory: UserMemory = .empty,
        embeddingMemory: EmbeddingMemoryStore? = nil,
        textEmbedding: (any TextEmbedding)? = nil
    ) {
        self.client = client
        self.configuration = configuration
        self.persona = persona
        self.memory = memory
        self.embeddingMemory = embeddingMemory
        self.textEmbedding = textEmbedding
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
        publishMessages()
    }

    /// Replaces the transcript from disk. This does not write the file again.
    public func replaceMessages(_ messages: [ChatMessage]) {
        self.messages = messages
        publish()
    }

    public func forget(noteID: UUID) {
        memory.notes.removeAll { $0.id == noteID }
        onProfileChange?()
        publish()
    }

    public func updatePersona(_ persona: CompanionPersona) {
        let name = persona.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.persona = CompanionPersona(
            name: name.isEmpty ? CompanionPersona.standard.name : name,
            personality: persona.personality.trimmingCharacters(in: .whitespacesAndNewlines),
            scenario: persona.scenario.trimmingCharacters(in: .whitespacesAndNewlines),
            greeting: persona.greeting.trimmingCharacters(in: .whitespacesAndNewlines)
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
        publishMessages()
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
        if !speaking {
            mouthLevel = 0
            viseme = "sil"
        }
        publish()
    }

    public func setMouthLevel(_ level: Double) {
        mouthLevel = min(1, max(0, level))
        if mouthLevel > peakMouth {
            peakMouth = mouthLevel
        }
        publish()
    }

    public func setViseme(_ viseme: String) {
        let next = viseme.trimmingCharacters(in: .whitespacesAndNewlines)
        self.viseme = next.isEmpty ? "sil" : next
        if self.viseme != "sil", self.viseme != "pp" {
            lastOpenViseme = self.viseme
        }
        publish()
    }

    /// Puts the last open speech mouth back after playback clears it.
    public func holdSpeechPose() {
        isSpeaking = true
        mouthLevel = peakMouth > 0.08 ? peakMouth : 1
        viseme = lastOpenViseme
        publish()
    }

    public func apply(vrm document: VRMDocument) {
        presentation = presentation.applying(document)
        showsModelTitle = true
        publish()
    }

    public func apply(scene: VRMScene) {
        vrmScene = scene
        presentation = presentation.applying(scene)
        showsModelTitle = scene.document.title != nil
        publish()
    }

    public func apply(scene: VRMScene, bytes: Data) {
        modelBytes = bytes
        apply(scene: scene)
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
            await storeEmbedding(note)
            onProfileChange?()
        }
        await recall(for: text)
        messages.append(ChatMessage(role: .user, content: text))
        var assistant = ChatMessage(role: .assistant, content: "")
        messages.append(assistant)
        phase = .streaming
        statusText = "Aori is writing."
        publishMessages()

        do {
            var receivedDelta = false
            var attempt = 0
            while true {
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
                            receivedDelta = true
                            assistant.content += piece
                            messages[messages.count - 1] = assistant
                            presentation.emotion = CompanionEmotion.infer(from: assistant.content)
                            publishMessages()
                        case .finished:
                            break
                        }
                    }
                    break
                } catch {
                    if receivedDelta || attempt > 0 {
                        throw error
                    }
                    attempt += 1
                    statusText = "Trying again."
                    publish()
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
        var systemPrompt = CompanionPrompt.system(persona: persona, memory: memory)
        let related = MemoryRecall.prompt(lines: recalledLines)
        if !related.isEmpty {
            systemPrompt += "\n\(related)"
        }
        var items = [ChatMessage(role: .system, content: systemPrompt)]
        let history = messages.dropLast()
        items.append(contentsOf: history)
        return items
    }

    private func storeEmbedding(_ text: String) async {
        guard let embeddingMemory, let textEmbedding else {
            return
        }
        let outcome = await textEmbedding.embed(text, configuration: configuration)
        embeddingMemory.insert(text: text, vector: outcome.vector.values, now: Date())
    }

    private func recall(for text: String) async {
        guard let embeddingMemory, let textEmbedding else {
            recalledLines = []
            recalledSummary = "none"
            return
        }
        let outcome = await textEmbedding.embed(text, configuration: configuration)
        let hits = embeddingMemory.recall(query: outcome.vector.values, limit: 3)
        recalledLines = hits.map(\.text)
        recalledSummary = recalledLines.first ?? "none"
    }

    private func publishMessages() {
        onTranscriptChange?()
        publish()
    }

    private func publish() {
        onChange?()
    }
}
