import AppKit
import AoriCore
import AoriProviders
import UniformTypeIdentifiers

@MainActor
enum AppHolder {
    static var delegate: AppDelegate?
}

@main
enum AoriMain {
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
    private let secrets = KeychainSecretStore(service: AoriSecrets.keychainService)
    private let profileStore = FileCompanionProfileStore(fileURL: AoriFiles.profileURL())
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
        let profile = loadProfile()
        let model = ChatViewModel(
            client: OpenAICompatibleClient(),
            configuration: configuration,
            persona: profile.persona,
            memory: profile.memory
        )
        self.model = model
        if let launchStatus {
            model.setStatus(launchStatus)
        } else if configuration.keySource == .missing {
            model.setStatus("No API key is set. Open Settings, or set AORI_OPENAI_API_KEY.")
        }

        let mainWindow = MainWindowController(model: model)
        mainWindow.onSend = { [weak self] in self?.sendDraft() }
        mainWindow.onSpeak = { [weak self] in self?.speakReply() }
        mainWindow.onListen = { [weak self] in self?.toggleListen() }
        self.mainWindow = mainWindow

        let companionWindow = CompanionWindowController(model: model, policy: companionPolicy)
        self.companionWindow = companionWindow

        let settingsWindow = SettingsWindowController(
            secrets: secrets,
            configuration: configuration,
            persona: profile.persona
        )
        settingsWindow.onSave = { [weak self] configuration in
            self?.model?.updateConfiguration(configuration)
            let source = configuration.keySource.rawValue
            self?.model?.setStatus("Saved the provider configuration. Key source: \(source).")
        }
        settingsWindow.onSavePersona = { [weak self] persona in
            self?.model?.updatePersona(persona)
        }
        self.settingsWindow = settingsWindow

        model.onChange = { [weak self] in
            self?.mainWindow?.refresh()
            self?.companionWindow?.refresh()
        }
        model.onProfileChange = { [weak self] in
            self?.saveProfile()
        }
        synthesizer.onSpeakingChanged = { [weak self] speaking in
            self?.model?.setSpeaking(speaking)
        }
        synthesizer.onMouthLevel = { [weak self] level in
            self?.model?.setMouthLevel(level)
        }
        loadSampleModel(into: model)

        mainWindow.showWindow(nil)
        companionWindow.showWindow(nil)
        model.greetIfNeeded()
        mainWindow.refresh()
        companionWindow.refresh()
        speakReply()
        NSApp.activate()
    }

    private func loadSampleModel(into model: ChatViewModel) {
        guard let data = SampleModel.data() else {
            model.setStatus("The sample VRM is not in the app bundle.")
            return
        }
        do {
            model.apply(scene: try VRMSceneReader.read(data))
        } catch {
            model.setStatus(String(describing: error))
        }
    }

    private func loadProfile() -> CompanionProfile {
        do {
            return try profileStore.load()
        } catch {
            launchStatus = String(describing: error)
            return .standard
        }
    }

    private func saveProfile() {
        guard let model else {
            return
        }
        let profile = CompanionProfile(persona: model.persona, memory: model.memory)
        do {
            try profileStore.save(profile)
        } catch {
            model.setStatus("The companion configuration was not saved. \(String(describing: error))")
        }
    }

    private func loadConfiguration() -> ProviderConfiguration {
        let resolver = ProviderConfigurationResolver(
            environment: ProcessInfo.processInfo.environment,
            secretStore: secrets,
            storedBaseURL: UserDefaults.standard.string(forKey: AoriPreferences.baseURLKey),
            storedModel: UserDefaults.standard.string(forKey: AoriPreferences.modelKey)
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
        alert.messageText = "Aori"
        alert.informativeText = "Aori is a desktop companion based on Project AIRI. The character is a VRM mesh drawn in AppKit. A Rust library moves the vertices. Speech levels move the mouth. Feelings move blend shapes."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func showSettings(_ sender: Any?) {
        guard let model else {
            return
        }
        settingsWindow?.refresh(configuration: model.configuration, persona: model.persona)
        settingsWindow?.showWindow(sender)
    }

    @objc func newChat(_ sender: Any?) {
        model?.clear()
        mainWindow?.setDraft("")
        model?.greetIfNeeded()
        speakReply()
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
            let scene = try VRMSceneReader.read(data)
            model?.apply(scene: scene)
            let title = scene.document.title ?? url.lastPathComponent
            model?.setStatus("Loaded \(title). \(scene.vertexCount) vertices.")
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

private enum AoriFiles {
    static func profileURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Aori", isDirectory: true)
        return directory.appendingPathComponent("companion.json")
    }
}
