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
        personaName: String
    ) -> String {
        [
            "Scene: \(sceneTitle). \(sceneDetail) Avatar \(avatar). Cubism, MMD, and Spine are absent.",
            "Providers: \(provider). Other providers are absent.",
            "Modules: chat, speech, vision, memory, and plugins. Games are absent.",
            "Character card: \(personaName). Other card fields are absent.",
            "Memory: \(noteCount) saved facts.",
            "Data: \(messageCount) messages in companion.sqlite.",
            "Connection: \(baseURL). Key source \(keySource).",
            "Models: \(model). Voice \(voice). The embedding file is aori-minilm.mlmodel.",
            "System: locale \(locale). Account sync is absent.",
        ].joined(separator: "\n")
    }
}
