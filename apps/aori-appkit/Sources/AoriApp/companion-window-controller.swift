import AppKit
import AoriCore

@MainActor
final class CompanionWindowController: NSWindowController {
    private let model: ChatViewModel
    private let characterView = CharacterView(frame: .zero)

    init(model: ChatViewModel, policy: CompanionWindowPolicy) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 380),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Aori Companion"
        window.minSize = NSSize(width: 220, height: 280)
        super.init(window: window)
        characterView.dragsWindow = true
        characterView.autoresizingMask = [.width, .height]
        window.contentView = characterView
        characterView.frame = window.contentView?.bounds ?? .zero
        apply(policy: policy)
        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: visible.maxX - 320, y: visible.minY + 48))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func apply(policy: CompanionWindowPolicy) {
        guard let window else {
            return
        }
        let style = policy.style()
        window.styleMask = style.borderless
            ? [.borderless, .resizable]
            : [.titled, .closable, .resizable]
        window.isOpaque = !style.transparent
        window.backgroundColor = style.transparent ? .clear : .windowBackgroundColor
        window.level = style.floating ? .floating : .normal
        var behavior: NSWindow.CollectionBehavior = [.fullScreenAuxiliary]
        if style.joinsAllSpaces {
            behavior.insert(.canJoinAllSpaces)
        }
        window.collectionBehavior = behavior
        window.isMovableByWindowBackground = style.movableByBackground
        window.hasShadow = !style.transparent
        characterView.clearsBackground = style.transparent
        characterView.dragsWindow = style.movableByBackground
    }

    func refresh() {
        characterView.apply(
            presentation: model.presentation,
            speaking: model.isSpeaking,
            mouthLevel: model.mouthLevel,
            scene: model.vrmScene
        )
    }
}
