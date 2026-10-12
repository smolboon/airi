import AppKit
import AoriCore

@MainActor
final class MainWindowController: NSWindowController {
    private let model: ChatViewModel
    private let characterView = CharacterView(frame: .zero)
    private let chatPanel = ChatPanelController()

    var onSend: (() -> Void)?
    var onSpeak: (() -> Void)?
    var onListen: (() -> Void)?

    init(model: ChatViewModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Aori"
        window.minSize = NSSize(width: 720, height: 480)
        super.init(window: window)

        characterView.clearsBackground = false
        characterView.dragsWindow = false
        characterView.translatesAutoresizingMaskIntoConstraints = true

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.autoresizingMask = [.width, .height]
        split.addArrangedSubview(characterView)
        split.addArrangedSubview(chatPanel.view)
        split.setPosition(300, ofDividerAt: 0)
        window.contentView = split
        if let content = window.contentView {
            split.frame = content.bounds
        }

        chatPanel.onSend = { [weak self] in self?.onSend?() }
        chatPanel.onSpeak = { [weak self] in self?.onSpeak?() }
        chatPanel.onListen = { [weak self] in self?.onListen?() }
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func refresh() {
        characterView.apply(presentation: model.presentation, speaking: model.isSpeaking)
        chatPanel.render(model)
    }

    func draftText() -> String {
        chatPanel.draftText()
    }

    func setDraft(_ text: String) {
        chatPanel.setDraft(text)
    }

    func setListening(_ listening: Bool) {
        chatPanel.setListening(listening)
    }
}
