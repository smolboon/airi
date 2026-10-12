import AppKit
import AiriCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let secrets: KeychainSecretStore
    private let baseField = NSTextField(string: "")
    private let modelField = NSTextField(string: "")
    private let keyField = NSSecureTextField(string: "")
    private let sourceLabel = NSTextField(wrappingLabelWithString: "")
    var onSave: ((ProviderConfiguration) -> Void)?

    init(secrets: KeychainSecretStore, configuration: ProviderConfiguration) {
        self.secrets = secrets
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        super.init(window: window)
        build()
        refresh(configuration: configuration)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func refresh(configuration: ProviderConfiguration) {
        baseField.stringValue = configuration.baseURL.absoluteString
        modelField.stringValue = configuration.model
        keyField.placeholderString = configuration.apiKey.isEmpty ? "API key" : "Saved. Type a new key to replace it."
        sourceLabel.stringValue = "Key source: \(configuration.keySource.rawValue). The key is not shown."
    }

    private func build() {
        let root = NSView()
        window?.contentView = root

        let baseLabel = NSTextField(labelWithString: "Base URL")
        let modelLabel = NSTextField(labelWithString: "Model")
        let keyLabel = NSTextField(labelWithString: "API key")
        sourceLabel.maximumNumberOfLines = 3
        sourceLabel.textColor = .secondaryLabelColor

        let save = NSButton(title: "Save", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        let remove = NSButton(title: "Remove Key", target: self, action: #selector(removeKey))
        remove.bezelStyle = .rounded

        let stack = NSStackView(views: [
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
            baseField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            keyField.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        keyField.setAccessibilityLabel("API key")
    }

    @objc private func save() {
        do {
            let configuration = try persist(removeKey: false)
            onSave?(configuration)
            refresh(configuration: configuration)
        } catch {
            sourceLabel.stringValue = String(describing: error)
        }
    }

    @objc private func removeKey() {
        do {
            try secrets.delete(account: AiriSecrets.openAIAPIKeyAccount)
            keyField.stringValue = ""
            let configuration = try persist(removeKey: true)
            onSave?(configuration)
            refresh(configuration: configuration)
        } catch {
            sourceLabel.stringValue = String(describing: error)
        }
    }

    private func persist(removeKey: Bool) throws -> ProviderConfiguration {
        let base = baseField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelName = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.isEmpty {
            UserDefaults.standard.set(base, forKey: AiriPreferences.baseURLKey)
        }
        if !modelName.isEmpty {
            UserDefaults.standard.set(modelName, forKey: AiriPreferences.modelKey)
        }
        let typedKey = keyField.stringValue
        if !removeKey, !typedKey.isEmpty {
            try secrets.write(account: AiriSecrets.openAIAPIKeyAccount, secret: typedKey)
            keyField.stringValue = ""
        }
        let resolver = ProviderConfigurationResolver(
            environment: ProcessInfo.processInfo.environment,
            secretStore: secrets,
            storedBaseURL: UserDefaults.standard.string(forKey: AiriPreferences.baseURLKey),
            storedModel: UserDefaults.standard.string(forKey: AiriPreferences.modelKey)
        )
        return try resolver.resolve()
    }
}
