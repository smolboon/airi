import AppKit
import AoriCore
import AVFoundation

@MainActor
final class SettingsWindowController: NSWindowController {
    private let secrets: KeychainSecretStore
    private let nameField = NSTextField(string: "")
    private let personalityField = NSTextField(string: "")
    private let scenarioField = NSTextField(string: "")
    private let greetingField = NSTextField(string: "")
    private let providerPopup = NSPopUpButton()
    private let voicePopup = NSPopUpButton()
    private let baseField = NSTextField(string: "")
    private let modelField = NSTextField(string: "")
    private let keyField = NSSecureTextField(string: "")
    private let memoryPopup = NSPopUpButton()
    private let pageLabel = NSTextField(wrappingLabelWithString: "")
    private let sourceLabel = NSTextField(wrappingLabelWithString: "")
    var onSave: ((ProviderConfiguration) -> Void)?
    var onSavePersona: ((CompanionPersona) -> Void)?
    var onDeleteNote: ((UUID) -> Void)?
    private let records: SQLiteCompanionStore
    private var notes: [MemoryNote] = []
    private var messageCount = 0
    private var localeID = "en"
    private var presentation = CharacterPresentation.placeholder

    init(
        secrets: KeychainSecretStore,
        configuration: ProviderConfiguration,
        persona: CompanionPersona,
        records: SQLiteCompanionStore
    ) {
        self.secrets = secrets
        self.records = records
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 920),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Aori Settings"
        window.appearance = NSAppearance(named: .darkAqua)
        super.init(window: window)
        build()
        settingsLog("aori_settings=provider,voice,model,persona,memory")
        settingsLog("aori_settings_pages=\(SettingsPages.ids.joined(separator: ","))")
        refresh(configuration: configuration, persona: persona, notes: [])
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func refresh(
        configuration: ProviderConfiguration,
        persona: CompanionPersona,
        notes: [MemoryNote],
        messageCount: Int = 0,
        locale: String = "en",
        presentation: CharacterPresentation = .placeholder
    ) {
        self.messageCount = messageCount
        self.localeID = locale
        self.presentation = presentation
        nameField.stringValue = persona.name
        personalityField.stringValue = persona.personality
        scenarioField.stringValue = persona.scenario
        greetingField.stringValue = persona.greeting
        baseField.stringValue = configuration.baseURL.absoluteString
        modelField.stringValue = configuration.model
        let stored = try? records.loadSettings()
        select(popup: providerPopup, value: stored?.provider ?? "openai")
        select(popup: voicePopup, value: stored?.voice ?? "")
        showNotes(notes)
        keyField.placeholderString = configuration.apiKey.isEmpty ? "API key" : "Saved. Type a new key to replace it."
        sourceLabel.stringValue = "Key source: \(configuration.keySource.rawValue). The key is not shown."
        let avatar = AvatarKind.resolve(ProcessInfo.processInfo.environment["AORI_AVATAR"]) == .layered ? "live2d" : "vrm"
        let voice = voicePopup.titleOfSelectedItem ?? "System default"
        pageLabel.stringValue = SettingsPages.report(
            sceneTitle: presentation.title,
            sceneDetail: presentation.subtitle,
            avatar: avatar,
            provider: stored?.provider ?? "openai",
            messageCount: messageCount,
            noteCount: notes.count,
            locale: locale,
            model: configuration.model,
            voice: voice,
            keySource: configuration.keySource.rawValue,
            baseURL: configuration.baseURL.absoluteString,
            personaName: persona.name
        )
    }

    func showNotes(_ notes: [MemoryNote]) {
        self.notes = notes
        memoryPopup.removeAllItems()
        if notes.isEmpty {
            memoryPopup.addItem(withTitle: "No saved facts")
            memoryPopup.lastItem?.representedObject = ""
            return
        }
        for note in notes {
            memoryPopup.addItem(withTitle: note.text)
            memoryPopup.lastItem?.representedObject = note.id.uuidString
        }
    }

    private func build() {
        let root = NSView()
        window?.contentView = root

        let nameLabel = NSTextField(labelWithString: "Name")
        let personalityLabel = NSTextField(labelWithString: "Personality")
        let scenarioLabel = NSTextField(labelWithString: "Scenario")
        let greetingLabel = NSTextField(labelWithString: "Greeting")
        let providerLabel = NSTextField(labelWithString: "Provider")
        let voiceLabel = NSTextField(labelWithString: "Voice")
        let baseLabel = NSTextField(labelWithString: "Base URL")
        let modelLabel = NSTextField(labelWithString: "Model")
        let keyLabel = NSTextField(labelWithString: "API key")
        let memoryLabel = NSTextField(labelWithString: "Saved facts")
        let pagesLabel = NSTextField(labelWithString: "Pages")
        pageLabel.maximumNumberOfLines = 12
        pageLabel.textColor = .secondaryLabelColor
        pageLabel.setAccessibilityLabel("Settings pages")
        sourceLabel.maximumNumberOfLines = 3
        sourceLabel.textColor = .secondaryLabelColor

        for option in LocalProviderCatalog.options {
            providerPopup.addItem(withTitle: option.title)
            providerPopup.lastItem?.representedObject = option.id
        }
        providerPopup.target = self
        providerPopup.action = #selector(providerChanged)
        providerPopup.setAccessibilityLabel("Provider")

        voicePopup.addItem(withTitle: "System default")
        voicePopup.lastItem?.representedObject = ""
        for voice in AVSpeechSynthesisVoice.speechVoices() {
            voicePopup.addItem(withTitle: "\(voice.name) (\(voice.language))")
            voicePopup.lastItem?.representedObject = voice.identifier
        }
        voicePopup.setAccessibilityLabel("Voice")

        memoryPopup.setAccessibilityLabel("Saved facts")

        let save = NSButton(title: "Save", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        let remove = NSButton(title: "Remove Key", target: self, action: #selector(removeKey))
        remove.bezelStyle = .rounded
        let deleteNote = NSButton(title: "Delete Fact", target: self, action: #selector(deleteFact))
        deleteNote.bezelStyle = .rounded
        deleteNote.setAccessibilityLabel("Delete saved fact")

        let stack = NSStackView(views: [
            pagesLabel, pageLabel,
            nameLabel, nameField,
            personalityLabel, personalityField,
            scenarioLabel, scenarioField,
            greetingLabel, greetingField,
            providerLabel, providerPopup,
            voiceLabel, voicePopup,
            baseLabel, baseField,
            modelLabel, modelField,
            keyLabel, keyField,
            sourceLabel,
            memoryLabel, memoryPopup,
            NSStackView(views: [save, remove, deleteNote]),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        for field in [nameField, personalityField, scenarioField, greetingField, baseField, modelField, keyField] {
            field.translatesAutoresizingMaskIntoConstraints = false
        }
        providerPopup.translatesAutoresizingMaskIntoConstraints = false
        voicePopup.translatesAutoresizingMaskIntoConstraints = false
        memoryPopup.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            nameField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            personalityField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scenarioField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            greetingField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            providerPopup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            voicePopup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            baseField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            keyField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            memoryPopup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            pageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        keyField.setAccessibilityLabel(AccessibilityCopy.apiKey)
    }

    @objc private func providerChanged() {
        let provider = memoryValue(providerPopup, fallback: "openai")
        baseField.stringValue = LocalProviderCatalog.resolvedBaseURL(
            provider: provider,
            current: baseField.stringValue
        )
    }

    @objc private func save() {
        do {
            let configuration = try persist(removeKey: false)
            onSavePersona?(currentPersona())
            onSave?(configuration)
            refresh(
                configuration: configuration,
                persona: currentPersona(),
                notes: notes,
                messageCount: messageCount,
                locale: localeID,
                presentation: presentation
            )
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
            refresh(
                configuration: configuration,
                persona: currentPersona(),
                notes: notes,
                messageCount: messageCount,
                locale: localeID,
                presentation: presentation
            )
        } catch {
            sourceLabel.stringValue = String(describing: error)
        }
    }

    @objc private func deleteFact() {
        let value = memoryPopup.selectedItem?.representedObject as? String ?? ""
        guard let id = UUID(uuidString: value) else {
            return
        }
        onDeleteNote?(id)
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
        var settings = (try? records.loadSettings()) ?? ProviderSettings(baseURL: "", model: "")
        if !base.isEmpty {
            settings.baseURL = base
        }
        if !modelName.isEmpty {
            settings.model = modelName
        }
        settings.provider = memoryValue(providerPopup, fallback: "openai")
        settings.voice = memoryValue(voicePopup, fallback: "")
        if !settings.baseURL.isEmpty || !settings.model.isEmpty || !settings.voice.isEmpty {
            try records.saveSettings(settings)
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
            personality: personalityField.stringValue,
            scenario: scenarioField.stringValue,
            greeting: greetingField.stringValue
        )
    }

    private func select(popup: NSPopUpButton, value: String) {
        for item in popup.itemArray {
            let stored = item.representedObject as? String ?? ""
            if stored == value {
                popup.select(item)
                return
            }
        }
        popup.selectItem(at: 0)
    }

    private func memoryValue(_ popup: NSPopUpButton, fallback: String) -> String {
        popup.selectedItem?.representedObject as? String ?? fallback
    }
}

private func settingsLog(_ line: String) {
    guard let data = (line + "\n").data(using: .utf8) else {
        return
    }
    FileHandle.standardOutput.write(data)
    try? FileHandle.standardOutput.synchronize()
}
