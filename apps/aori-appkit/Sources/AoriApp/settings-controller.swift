import AppKit
import AoriCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let secrets: KeychainSecretStore
    private let nameField = NSTextField(string: "")
    private let personalityField = NSTextField(string: "")
    private let baseField = NSTextField(string: "")
    private let modelField = NSTextField(string: "")
    private let keyField = NSSecureTextField(string: "")
    private let sourceLabel = NSTextField(wrappingLabelWithString: "")
    var onSave: ((ProviderConfiguration) -> Void)?
    var onSavePersona: ((CompanionPersona) -> Void)?
    private let settingsFileURL: URL

    init(
        secrets: KeychainSecretStore,
        configuration: ProviderConfiguration,
        persona: CompanionPersona,
        settingsFileURL: URL
    ) {
        self.secrets = secrets
        self.settingsFileURL = settingsFileURL
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        super.init(window: window)
        build()
        refresh(configuration: configuration, persona: persona)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func refresh(configuration: ProviderConfiguration, persona: CompanionPersona) {
        nameField.stringValue = persona.name
        personalityField.stringValue = persona.personality
        baseField.stringValue = configuration.baseURL.absoluteString
        modelField.stringValue = configuration.model
        keyField.placeholderString = configuration.apiKey.isEmpty ? "API key" : "Saved. Type a new key to replace it."
        sourceLabel.stringValue = "Key source: \(configuration.keySource.rawValue). The key is not shown. Say remember that ... in chat to store a fact."
    }

    private func build() {
        let root = NSView()
        window?.contentView = root

        let nameLabel = NSTextField(labelWithString: "Name")
        let personalityLabel = NSTextField(labelWithString: "Personality")
        let baseLabel = NSTextField(labelWithString: "Base URL")
        let modelLabel = NSTextField(labelWithString: "Model")
        let keyLabel = NSTextField(labelWithString: "API key")
        sourceLabel.maximumNumberOfLines = 4
        sourceLabel.textColor = .secondaryLabelColor

        let save = NSButton(title: "Save", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        let remove = NSButton(title: "Remove Key", target: self, action: #selector(removeKey))
        remove.bezelStyle = .rounded

        let stack = NSStackView(views: [
            nameLabel, nameField,
            personalityLabel, personalityField,
            baseLabel, baseField,
            modelLabel, modelField,
            keyLabel, keyField,
            sourceLabel,
            NSStackView(views: [save, remove]),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        baseField.translatesAutoresizingMaskIntoConstraints = false
        modelField.translatesAutoresizingMaskIntoConstraints = false
        keyField.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            nameField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            personalityField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            baseField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            keyField.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        keyField.setAccessibilityLabel("API key")
    }

    @objc private func save() {
        do {
            let configuration = try persist(removeKey: false)
            onSavePersona?(currentPersona())
            onSave?(configuration)
            refresh(configuration: configuration, persona: currentPersona())
        } catch {
            sourceLabel.stringValue = String(describing: error)
        }
    }

    @objc private func removeKey() {
        do {
            try secrets.delete(account: AoriSecrets.openAIAPIKeyAccount)
            keyField.stringValue = ""
            let configuration = try persist(removeKey: true)
            onSave?(configuration)
            refresh(configuration: configuration, persona: currentPersona())
        } catch {
            sourceLabel.stringValue = String(describing: error)
        }
    }

    private func persist(removeKey: Bool) throws -> ProviderConfiguration {
        let base = baseField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelName = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.isEmpty {
            UserDefaults.standard.set(base, forKey: AoriPreferences.baseURLKey)
        }
        if !modelName.isEmpty {
            UserDefaults.standard.set(modelName, forKey: AoriPreferences.modelKey)
        }
        let store = FileProviderSettingsStore(fileURL: settingsFileURL)
        var settings = (try? store.load()) ?? ProviderSettings(baseURL: "", model: "")
        if !base.isEmpty {
            settings.baseURL = base
        }
        if !modelName.isEmpty {
            settings.model = modelName
        }
        if !settings.baseURL.isEmpty || !settings.model.isEmpty {
            try store.save(settings)
        }
        let typedKey = keyField.stringValue
        if !removeKey, !typedKey.isEmpty {
            try secrets.write(account: AoriSecrets.openAIAPIKeyAccount, secret: typedKey)
            keyField.stringValue = ""
        }
        let resolver = ProviderConfigurationResolver(
            environment: ProcessInfo.processInfo.environment,
            secretStore: secrets,
            storedBaseURL: UserDefaults.standard.string(forKey: AoriPreferences.baseURLKey),
            storedModel: UserDefaults.standard.string(forKey: AoriPreferences.modelKey)
        )
        return try resolver.resolve()
    }

    private func currentPersona() -> CompanionPersona {
        CompanionPersona(
            name: nameField.stringValue,
            personality: personalityField.stringValue
        )
    }
}
