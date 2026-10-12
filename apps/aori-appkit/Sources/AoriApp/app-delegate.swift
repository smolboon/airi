import AppKit
import ApplicationServices
import AoriCore
import CoreGraphics
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
    private let localeStore = FileLocalePreferenceStore(fileURL: AoriFiles.localeURL())
    private var model: ChatViewModel?
    private var mainWindow: MainWindowController?
    private var companionWindow: CompanionWindowController?
    private var settingsWindow: SettingsWindowController?
    private let synthesizer = AppleSpeechSynthesizer()
    private let transcriber = AppleSpeechTranscriber()
    private var companionPolicy = CompanionWindowPolicy.standard
    private var alwaysOnTopItem: NSMenuItem?
    private var clickThroughItem: NSMenuItem?
    private var statusItem: StatusItemController?
    private var listening = false
    private var launchStatus: String?
    private var localeID = "en"
    private var turn = VoiceTurn()
    private var heardSamples: [Float] = []
    private var heardText = ""
    private var voiceActivity = VoiceActivity.standard

    func applicationWillFinishLaunching(_ notification: Notification) {
        applyLocale(initialLocale(), persist: false)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        launch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func installMenu() {
        let menu = MenuBuilder.install(target: self, localeID: localeID)
        alwaysOnTopItem = menu.alwaysOnTopItem
        alwaysOnTopItem?.state = companionPolicy.alwaysOnTop ? .on : .off
        clickThroughItem = menu.clickThroughItem
        clickThroughItem?.state = companionPolicy.clickThrough ? .on : .off
    }

    private func launch() {
        statusItem = StatusItemController(target: self)
        let configuration = loadConfiguration()
        let profile = loadProfile()
        let model = ChatViewModel(
            client: RoutingChatClient(),
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
        startHandsFree()
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
        logClickThrough()
        deliverClickThrough()
        logAccessibilityTree()
        logLine("aori_mic_probe=begin")
        logLine("aori_mic_utterance=\(transcriber.captureUtterance())")
        Task {
            logLine("aori_accessibility=\(AccessibilityCopy.proof)")
            logLine(KeychainProbe.line(store: self.secrets))
            let mic = self.transcriber.probeMicrophone()
            logLine("aori_mic=\(mic)")
            await self.synthesizer.speak("Hello papa")
            await self.runFixtureTurn()
            logLine("aori_turn=done")
        }
        Timer.scheduledTimer(withTimeInterval: 80, repeats: false) { _ in
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
        logLine(AoriLog.frame(milliseconds: milliseconds))
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

    @objc func selectLocale(_ sender: NSMenuItem?) {
        let id = sender?.representedObject as? String ?? "en"
        applyLocale(id, persist: true)
    }

    @objc func toggleAlwaysOnTop(_ sender: Any?) {
        companionPolicy.alwaysOnTop.toggle()
        alwaysOnTopItem?.state = companionPolicy.alwaysOnTop ? .on : .off
        companionWindow?.apply(policy: companionPolicy)
    }

    @objc func toggleClickThrough(_ sender: Any?) {
        companionPolicy.clickThrough.toggle()
        clickThroughItem?.state = companionPolicy.clickThrough ? .on : .off
        companionWindow?.apply(policy: companionPolicy)
    }

    private func logClickThrough() {
        logLine("aori_click_through=\(companionPolicy.clickThrough ? "on" : "off")")
        guard let sample = companionWindow?.clickThroughSample() else {
            return
        }
        logLine("aori_hit_corner=\(sample.corner)")
        logLine("aori_hit_body=\(sample.body)")
        logLine("aori_ignores_mouse=\(sample.ignoresMouse)")
    }

    private func deliverClickThrough() {
        guard let companion = companionWindow?.window,
              let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        else {
            logLine("aori_click_post=no-screen")
            logLine("aori_click_through=missed")
            return
        }
        let behind = BehindClickWindow()
        behind.place(under: companion.frame)
        companion.level = .floating
        companion.orderFrontRegardless()
        companionWindow?.holdMouseIgnore(true)
        companion.ignoresMouseEvents = true
        companion.displayIfNeeded()
        behind.window.displayIfNeeded()
        let appKitPoint = NSPoint(x: companion.frame.minX + 4, y: companion.frame.maxY - 4)
        let point = CGPoint(
            x: appKitPoint.x,
            y: ClickThrough.coreGraphicsY(appKitY: appKitPoint.y, screenHeight: screen.frame.height)
        )
        logLine(String(format: "aori_click_point=%.1f,%.1f", appKitPoint.x, appKitPoint.y))
        logLine("aori_click_post=\(postClick(at: point))")
        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        let serverTarget = NSWindow.windowNumber(at: appKitPoint, belowWindowWithWindowNumber: 0)
        let behindNumber = behind.window.windowNumber
        logLine("aori_click_target=\(serverTarget)")
        logLine("aori_click_behind=\(behindNumber)")
        if serverTarget == behindNumber {
            sendClick(to: behind.window, screenPoint: appKitPoint)
            if behind.hits == 0 {
                deliverClick(to: behind.window, screenPoint: appKitPoint)
            }
        }
        companionWindow?.holdMouseIgnore(false)
        let delivered = behind.hits > 0 && serverTarget == behindNumber
        logLine("aori_click_hits=\(behind.hits)")
        logLine(delivered ? "aori_click_through=delivered" : "aori_click_through=missed")
    }

    private func sendClick(to window: NSWindow, screenPoint: NSPoint) {
        let local = window.convertPoint(fromScreen: screenPoint)
        let down = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: local,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        )
        let up = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: local,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        )
        if let down {
            window.sendEvent(down)
        }
        if let up {
            window.sendEvent(up)
        }
    }

    private func deliverClick(to window: NSWindow, screenPoint: NSPoint) {
        let local = window.convertPoint(fromScreen: screenPoint)
        guard let view = window.contentView else {
            return
        }
        let point = view.convert(local, from: nil)
        guard view.bounds.contains(point), let down = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 1
        ) else {
            logLine(String(format: "aori_click_local=%.1f,%.1f", point.x, point.y))
            return
        }
        view.mouseDown(with: down)
    }

    private func postClick(at point: CGPoint) -> String {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDown,
                mouseCursorPosition: point,
                mouseButton: .left
              ),
              let up = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: .left
              )
        else {
            return "none"
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        return "posted"
    }

    private func logAccessibilityTree() {
        var labels: [String] = []
        func add(_ label: String?) {
            guard let label, !label.isEmpty, !labels.contains(label) else {
                return
            }
            labels.append(label)
        }
        func walkView(_ view: NSView) {
            add(view.accessibilityLabel())
            for subview in view.subviews {
                walkView(subview)
            }
        }
        func walkElement(_ element: AXUIElement, depth: Int) {
            guard depth < 12 else {
                return
            }
            add(axString(element, kAXTitleAttribute))
            add(axString(element, kAXDescriptionAttribute))
            var children: CFTypeRef?
            let copied = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
            guard copied == .success, let list = children as? [AXUIElement] else {
                return
            }
            for child in list {
                walkElement(child, depth: depth + 1)
            }
        }
        let windows = [mainWindow?.window, companionWindow?.window].compactMap { $0 }
        for window in windows where window.isVisible {
            add(window.accessibilityLabel())
            if let content = window.contentView {
                walkView(content)
            }
        }
        walkElement(AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier), depth: 0)
        logLine("aori_ax=\(labels.joined(separator: "|"))")
        if let pressed = mainWindow?.pressSendForAccessibility(), !pressed.isEmpty {
            logLine("aori_ax_press=\(pressed)")
        }
    }

    private func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        let copied = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard copied == .success else {
            return nil
        }
        return value as? String
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

    private func initialLocale() -> String {
        if let env = ProcessInfo.processInfo.environment["AORI_LOCALE"], LocaleCatalog.ids.contains(env) {
            return env
        }
        if let saved = try? localeStore.load(), LocaleCatalog.ids.contains(saved) {
            return saved
        }
        return "en"
    }

    private func localesRoot() -> URL {
        if let path = ProcessInfo.processInfo.environment["AORI_LOCALES_ROOT"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/locales", isDirectory: true)
        if FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        return bundled
    }

    private func applyLocale(_ id: String, persist: Bool) {
        let choice = LocaleCatalog.ids.contains(id) ? id : "en"
        localeID = choice
        let loaded = LocaleCatalog.load(root: localesRoot(), id: choice)
        if let menu = loaded.menuText, menu.contains("showCompanion") {
            AoriCopy.load(menu)
            logLine("aori_locale_menu=loaded")
            logLine("aori_i18n=loaded")
        } else if let english = LocaleFile.englishMenu() {
            AoriCopy.load(english)
            logLine("aori_locale_menu=fallback")
            logLine("aori_i18n=loaded")
        } else {
            logLine("aori_locale_menu=fallback")
            logLine("aori_i18n=fallback")
        }
        logLine("aori_locale=\(choice)")
        logLine("aori_locale_proof=\(loaded.proof)")
        if persist {
            try? localeStore.save(id: choice)
        }
        installMenu()
    }

    private func runFixtureTurn() async {
        let path = ProcessInfo.processInfo.environment["AORI_SPEECH_WAV"] ?? ""
        guard !path.isEmpty, let data = try? Data(contentsOf: URL(fileURLWithPath: path)), let decoded = WavFile.decode(data) else {
            logLine("aori_vad=missing")
            logLine("aori_stt=missing")
            logLine("aori_llm=skipped")
            return
        }
        let activity = VoiceActivity(threshold: 0.02, silenceSeconds: 0.2, sampleRate: Double(decoded.sampleRate))
        logLine(activity.containsSpeech(decoded.samples) ? "aori_vad=speech" : "aori_vad=silence")
        let status = await transcriber.authorization(timeout: 5)
        logLine("aori_stt_auth=\(status.rawValue)")
        let text: String
        if status == .granted {
            logLine("aori_stt_engine=speech")
            text = await transcriber.transcribeFile(at: URL(fileURLWithPath: path))
        } else if let recognizer = OnDeviceRecognizer.fromEnvironment() {
            logLine("aori_stt_engine=whisper")
            text = (try? recognizer.transcribe(wavPath: path)) ?? ""
        } else {
            logLine("aori_stt_engine=missing")
            text = ""
        }
        let heard = text.trimmingCharacters(in: .whitespacesAndNewlines)
        logLine("aori_stt=\(heard.isEmpty ? "empty" : heard)")
        if !heard.isEmpty {
            var fixture = VoiceTurn()
            if case .send(let line) = fixture.hear(utterance: heard) {
                logLine(AoriLog.event("turn", fields: ["step": "send", "text": line]))
            }
        }
        guard !heard.isEmpty, let model else {
            logLine("aori_llm=skipped")
            await synthesizer.speak("I am here.")
            return
        }
        model.setDraft(heard)
        await model.send()
        let usesLocal = model.configuration.apiKey.isEmpty || model.configuration.model == "local"
        logLine(usesLocal ? "aori_llm=local" : "aori_llm=sent")
        if let reply = model.textForSpeech() {
            logLine("aori_llm_reply=\(reply)")
            await synthesizer.speak(reply)
        }
    }

    private func startHandsFree() {
        Task {
            let mic = self.transcriber.probeMicrophone()
            logLine("aori_mic=\(mic)")
            let permission = await self.transcriber.requestAuthorization()
            guard permission == .granted else {
                logLine("aori_listen=denied")
                return
            }
            do {
                self.listening = true
                try self.transcriber.start { [weak self] text in
                    Task { @MainActor in
                        self?.heardText = text
                    }
                } onSamples: { [weak self] samples, rate in
                    Task { @MainActor in
                        self?.noteSamples(samples, rate: rate)
                    }
                }
                self.mainWindow?.setListening(true)
                self.model?.setStatus("Listening.")
                logLine("aori_listen=started")
            } catch {
                self.listening = false
                logLine("aori_listen=unavailable")
                self.model?.setStatus(String(describing: error))
            }
        }
    }

    private func noteSamples(_ samples: [Float], rate: Double) {
        guard listening, !samples.isEmpty else {
            return
        }
        if rate > 0 {
            voiceActivity.sampleRate = rate
        }
        heardSamples.append(contentsOf: samples)
        let cap = Int(voiceActivity.sampleRate * 8)
        if heardSamples.count > cap {
            heardSamples.removeFirst(heardSamples.count - cap)
        }
        guard voiceActivity.endpoint(heardSamples) else {
            return
        }
        let text = heardText.trimmingCharacters(in: .whitespacesAndNewlines)
        heardSamples = []
        guard !text.isEmpty else {
            return
        }
        heardText = ""
        transcriber.stop()
        listening = false
        mainWindow?.setListening(false)
        handleUtterance(text)
    }

    private func handleUtterance(_ text: String) {
        let action = turn.hear(utterance: text)
        guard case .send(let spoken) = action else {
            startHandsFree()
            return
        }
        logLine(AoriLog.event("turn", fields: ["step": "send"]))
        model?.setDraft(spoken)
        mainWindow?.setDraft("")
        Task {
            await self.model?.send()
            let reply = self.model?.textForSpeech() ?? ""
            let usesLocal = self.model?.configuration.apiKey.isEmpty != false || self.model?.configuration.model == "local"
            logLine(usesLocal ? "aori_llm=local" : "aori_llm=sent")
            if !reply.isEmpty, case .speak = self.turn.acceptReply(reply) {
                await self.synthesizer.speak(reply)
            }
            self.turn.finishSpeech()
            self.startHandsFree()
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
                    self?.heardText = text
                    self?.model?.applyTranscript(text)
                    self?.mainWindow?.setDraft(text)
                }
            } onSamples: { [weak self] samples, rate in
                Task { @MainActor in
                    self?.noteSamples(samples, rate: rate)
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

    static func localeURL() -> URL {
        directory().appendingPathComponent("locale.json")
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
