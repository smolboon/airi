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
        cardModules: String
    ) -> String {
        [
            "Scene: \(sceneTitle). \(sceneDetail) Avatar \(avatar). Cubism, MMD, and Spine are absent.",
            "Providers: OpenAI-compatible, MLX-Serve, and TensorFold. Selected \(LocalProviderCatalog.title(for: provider)). Other catalogs are absent.",
            "Modules: chat, speech, vision, memory, and plugins. Games are absent.",
            "Character card: \(personaName). Fields: name, nickname, description, personality, scenario, greeting, alternate greetings, creator notes, lore, tags, system prompt, post-history instructions, card version, and modules. Card modules: \(cardModules). A keyword lorebook is absent.",
            "Memory: \(noteCount) saved facts.",
            "Data: \(messageCount) messages in companion.sqlite.",
            "Connection: \(baseURL). Key source \(keySource).",
            "Models: \(model). Voice \(voice). The embedding file is aori-minilm.mlmodel.",
            "System: locale \(locale). Account sync is absent.",
        ].joined(separator: "\n")
    }
}
