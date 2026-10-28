import Foundation

public enum SettingsPages {
    public static let ids = [
        "scene",
        "providers",
        "modules",
        "card",
        "memory",
        "data",
        "connection",
        "models",
        "system",
    ]

    public static func report(
        sceneTitle: String,
        sceneDetail: String,
        avatar: String,
        provider: String,
        messageCount: Int,
        noteCount: Int,
        locale: String,
        model: String,
        voice: String,
        keySource: String,
        baseURL: String,
        personaName: String,
        cardModules: String,
        lorebookCount: Int
    ) -> String {
        [
            "Scene: \(sceneTitle). \(sceneDetail) Avatar \(avatar). Cubism, MMD, and Spine are absent.",
            "Providers: OpenAI-compatible, MLX-Serve, TensorFold, Ollama, and LM Studio. Selected \(LocalProviderCatalog.title(for: provider)). Other catalogs are absent.",
            "Modules: chat, speech, vision, memory, and plugins. \(GameScaffold.report())",
            IntegrationScaffold.report(),
            "Character card: \(personaName). Fields: name, nickname, description, personality, scenario, greeting, alternate greetings, creator notes, lore, tags, system prompt, post-history instructions, card version, modules, and a keyword lorebook. Card modules: \(cardModules). Keyword lorebook: \(lorebookCount) entries.",
            "Memory: \(noteCount) saved facts.",
            "Data: \(messageCount) messages in companion.sqlite. The chat server receives the latest \(CompanionPrompt.providerHistoryLimit) lines.",
            "Connection: \(baseURL). Key source \(keySource).",
            "Models: \(model). Voice \(voice). The embedding file is aori-minilm.mlmodel.",
            "System: locale \(locale). \(ChatProtocolScaffold.report()) Account sync is absent.",
        ].joined(separator: "\n")
    }
}
