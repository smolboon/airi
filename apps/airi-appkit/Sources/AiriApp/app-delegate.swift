import AppKit
import AiriCore
import AiriProviders
import UniformTypeIdentifiers

@MainActor
enum AppHolder {
    static var delegate: AppDelegate?
}

@main
enum AiriMain {
    static func main() {
        // NSApplication starts on the main thread. The delegate is retained for the process lifetime.
        MainActor.assumeIsolated {
            let delegate = AppDelegate()
            AppHolder.delegate = delegate
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            app.delegate = delegate
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let secrets = KeychainSecretStore(service: AiriSecrets.keychainService)
    private var model: ChatViewModel?
    private var mainWindow: MainWindowController?
    private var companionWindow: CompanionWindowController?
    private var settingsWindow: SettingsWindowController?
    private let synthesizer = AppleSpeechSynthesizer()
    private let transcriber = AppleSpeechTranscriber()
    private var companionPolicy = CompanionWindowPolicy.standard
    private var alwaysOnTopItem: NSMenuItem?
    private var listening = false
    private var launchStatus: String?

    func applicationWillFinishLaunching(_ notification: Notification) {
        installMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        launch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func installMenu() {
        let menu = MenuBuilder.install(target: self)
        alwaysOnTopItem = menu.alwaysOnTopItem
        alwaysOnTopItem?.state = companionPolicy.alwaysOnTop ? .on : .off
    }

    private func launch() {
        let configuration = loadConfiguration()
        let model = ChatViewModel(client: OpenAICompatibleClient(), configuration: configuration)
        self.model = model
        if let launchStatus {
            model.setStatus(launchStatus)
        } else if configuration.keySource == .missing {
            model.setStatus("No API key is set. Open Settings, or set AIRI_OPENAI_API_KEY.")
        }

        let mainWindow = MainWindowController(model: model)
        mainWindow.onSend = { [weak self] in self?.sendDraft() }
        mainWindow.onSpeak = { [weak self] in self?.speakReply() }
        mainWindow.onListen = { [weak self] in self?.toggleListen() }
        self.mainWindow = mainWindow

        let companionWindow = CompanionWindowController(model: model, policy: companionPolicy)
        self.companionWindow = companionWindow

        let settingsWindow = SettingsWindowController(secrets: secrets, configuration: configuration)
        settingsWindow.onSave = { [weak self] configuration in
            self?.model?.updateConfiguration(configuration)
            let source = configuration.keySource.rawValue
            self?.model?.setStatus("Saved the provider configuration. Key source: \(source).")
        }
        self.settingsWindow = settingsWindow

        model.onChange = { [weak self] in
            self?.mainWindow?.refresh()
            self?.companionWindow?.refresh()
        }
        synthesizer.onSpeakingChanged = { [weak self] speaking in
            self?.model?.setSpeaking(speaking)
        }

        mainWindow.showWindow(nil)
        companionWindow.showWindow(nil)
        mainWindow.refresh()
        companionWindow.refresh()
        NSApp.activate()
    }

    private func loadConfiguration() -> ProviderConfiguration {
        let resolver = ProviderConfigurationResolver(
            environment: ProcessInfo.processInfo.environment,
            secretStore: secrets,
            storedBaseURL: UserDefaults.standard.string(forKey: AiriPreferences.baseURLKey),
            storedModel: UserDefaults.standard.string(forKey: AiriPreferences.modelKey)
        )
        do {
            return try resolver.resolve()
        } catch {
            launchStatus = String(describing: error)
            return ProviderConfiguration(
                baseURL: URL(string: "https://api.openai.com/v1") ?? URL(fileURLWithPath: "/"),
                model: "gpt-4o-mini",
                apiKey: "",
                keySource: .missing
            )
        }
    }

    @objc func showAbout(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "AIRI"
        alert.informativeText = "Milestone 1 is a native macOS companion shell. Chat uses an OpenAI-compatible provider. The character is a SceneKit placeholder."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func showSettings(_ sender: Any?) {
        guard let model else {
            return
        }
        settingsWindow?.refresh(configuration: model.configuration)
        settingsWindow?.showWindow(sender)
    }

    @objc func newChat(_ sender: Any?) {
        model?.clear()
        mainWindow?.setDraft("")
    }

    @objc func openVRM(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ["vrm", "glb"].compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let document = try VRMDocumentReader.read(data)
            model?.apply(vrm: document)
            let title = document.title ?? url.lastPathComponent
            model?.setStatus("Loaded VRM metadata for \(title). The mesh is still the placeholder.")
        } catch {
            model?.setStatus(String(describing: error))
        }
    }

    @objc func showMainWindow(_ sender: Any?) {
        mainWindow?.showWindow(sender)
        mainWindow?.window?.makeKeyAndOrderFront(sender)
    }

    @objc func showCompanion(_ sender: Any?) {
        companionWindow?.apply(policy: companionPolicy)
        companionWindow?.showWindow(sender)
        companionWindow?.window?.orderFrontRegardless()
    }

    @objc func hideCompanion(_ sender: Any?) {
        companionWindow?.window?.orderOut(sender)
    }

    @objc func toggleAlwaysOnTop(_ sender: Any?) {
        companionPolicy.alwaysOnTop.toggle()
        alwaysOnTopItem?.state = companionPolicy.alwaysOnTop ? .on : .off
        companionWindow?.apply(policy: companionPolicy)
    }

    private func sendDraft() {
        guard let model, let mainWindow else {
            return
        }
        let text = mainWindow.draftText()
        mainWindow.setDraft("")
        model.setDraft(text)
        Task {
            await model.send()
            mainWindow.setDraft(model.draft)
        }
    }

    private func speakReply() {
        guard let text = model?.textForSpeech() else {
            model?.setStatus("There is no reply to speak.")
            return
        }
        Task {
            await synthesizer.speak(text)
        }
    }

    private func toggleListen() {
        Task {
            await self.toggleListenAsync()
        }
    }

    private func toggleListenAsync() async {
        if listening {
            transcriber.stop()
            listening = false
            mainWindow?.setListening(false)
            model?.setStatus("")
            return
        }
        let permission = await transcriber.requestAuthorization()
        guard permission == .granted else {
            model?.setStatus("Microphone or speech recognition permission is not granted.")
            return
        }
        do {
            try transcriber.start { [weak self] text in
                Task { @MainActor in
                    self?.model?.applyTranscript(text)
                    self?.mainWindow?.setDraft(text)
                }
            }
            listening = true
            mainWindow?.setListening(true)
            model?.setStatus("Listening.")
        } catch {
            model?.setStatus(String(describing: error))
        }
    }
}
