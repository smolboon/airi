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
    private let transcriptStore = FileChatTranscriptStore(fileURL: AoriFiles.chatURL())
    private let settingsStore = FileProviderSettingsStore(fileURL: AoriFiles.settingsURL())
    private var model: ChatViewModel?
    private var mainWindow: MainWindowController?
    private var companionWindow: CompanionWindowController?
    private var settingsWindow: SettingsWindowController?
    private let synthesizer = AppleSpeechSynthesizer()
    private let transcriber = AppleSpeechTranscriber()
    private var companionPolicy = CompanionWindowPolicy.standard
    private var alwaysOnTopItem: NSMenuItem?
    private var statusItem: StatusItemController?
    private var listening = false
    private var launchStatus: String?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if let text = LocaleFile.englishMenu() {
            AoriCopy.load(text)
            logLine("aori_i18n=loaded")
        } else {
            logLine("aori_i18n=fallback")
        }
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
        statusItem = StatusItemController(target: self)
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
            persona: profile.persona,
            settingsFileURL: AoriFiles.settingsURL()
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
        model.onTranscriptChange = { [weak self] in
            self?.saveTranscript()
        }
        synthesizer.onSpeakingChanged = { [weak self] speaking in
            self?.model?.setSpeaking(speaking)
        }
        synthesizer.onMouthLevel = { [weak self] level in
            self?.model?.setMouthLevel(level)
        }
        synthesizer.onViseme = { [weak self] name in
            self?.model?.setViseme(name)
        }
        loadSampleModel(into: model)
        if let saved = try? transcriptStore.load(), !saved.isEmpty {
            model.replaceMessages(saved)
        }

        mainWindow.showWindow(nil)
        companionWindow.showWindow(nil)
        model.greetIfNeeded()
        mainWindow.refresh()
        companionWindow.refresh()
        if screenshotMode {
            presentScreenshot()
            return
        }
        speakReply()
        NSApp.activate()
    }

    private var screenshotMode: Bool {
        ProcessInfo.processInfo.environment["AORI_SCREENSHOT"] == "1"
    }

    private func presentScreenshot() {
        model?.setSpeaking(true)
        model?.setMouthLevel(ScreenshotPose.mouthOpen)
        model?.setViseme("a")
        mainWindow?.refresh()
        companionWindow?.refresh()
        companionWindow?.window?.orderFrontRegardless()
        NSApp.activate()
        writeFramebuffer()
        Task {
            await synthesizer.speak("Hello papa")
        }
        Timer.scheduledTimer(withTimeInterval: 40, repeats: false) { _ in
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }

    private func writeFramebuffer() {
        let started = Date()
        guard let png = companionWindow?.renderedPNG(time: ScreenshotPose.time) else {
            model?.setStatus("The screenshot frame was not rendered.")
            return
        }
        let milliseconds = Date().timeIntervalSince(started) * 1000
        logLine(String(format: "aori_frame_ms=%.2f", milliseconds))
        let path = ProcessInfo.processInfo.environment["AORI_FRAMEBUFFER_PATH"] ?? "/tmp/aori-framebuffer.png"
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            model?.setStatus("The screenshot frame was not written. \(String(describing: error))")
        }
    }

    private func loadSampleModel(into model: ChatViewModel) {
        let data: Data
        if let path = ProcessInfo.processInfo.environment["AORI_VRM_PATH"], !path.isEmpty {
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: path))
            } catch {
                model.setStatus(String(describing: error))
                return
            }
            logLine("aori_vrm_path=\(path)")
        } else if let bundled = SampleModel.data() {
            data = bundled
        } else {
            model.setStatus("The sample VRM is not in the app bundle.")
            return
        }
        do {
            let scene = try VRMSceneReader.read(data)
            model.apply(scene: scene, bytes: data)
            let bones = (try? VRMHumanoidReader.bones(in: data)) ?? []
            if !bones.isEmpty {
                logLine("aori_vrm_bones=\(bones.map(\.name).joined(separator: ","))")
            }
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

    private func saveTranscript() {
        guard let model else {
            return
        }
        do {
            try transcriptStore.save(model.messages)
        } catch {
            model.setStatus("The chat history was not saved. \(String(describing: error))")
        }
    }

    private func loadConfiguration() -> ProviderConfiguration {
        let stored = try? settingsStore.load()
        let resolver = ProviderConfigurationResolver(
            environment: ProcessInfo.processInfo.environment,
            secretStore: secrets,
            storedBaseURL: nonBlank(stored?.baseURL) ?? UserDefaults.standard.string(forKey: AoriPreferences.baseURLKey),
            storedModel: nonBlank(stored?.model) ?? UserDefaults.standard.string(forKey: AoriPreferences.modelKey)
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
        alert.informativeText = "Aori is a desktop companion based on Project AIRI. The character is a rigged VRM humanoid. A Rust library skins the mesh and fills a depth buffer. Speech visemes move the mouth."
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
            model?.apply(scene: scene, bytes: data)
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
    static func directory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Aori", isDirectory: true)
    }

    static func profileURL() -> URL {
        directory().appendingPathComponent("companion.json")
    }

    static func chatURL() -> URL {
        directory().appendingPathComponent("chat.json")
    }

    static func settingsURL() -> URL {
        directory().appendingPathComponent("settings.json")
    }
}

private func nonBlank(_ text: String?) -> String? {
    guard let text else {
        return nil
    }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func logLine(_ line: String) {
    guard let data = (line + "\n").data(using: .utf8) else {
        return
    }
    FileHandle.standardOutput.write(data)
    try? FileHandle.standardOutput.synchronize()
}
