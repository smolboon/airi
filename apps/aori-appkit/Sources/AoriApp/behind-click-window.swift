import AppKit

/// A normal window that counts clicks which pass the companion window.
@MainActor
final class BehindClickWindow {
    let window: NSWindow
    private let view = BehindClickView(frame: .zero)

    var hits: Int {
        view.hits
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Aori Behind"
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false
        view.autoresizingMask = [.width, .height]
        window.contentView = view
        view.frame = window.contentView?.bounds ?? .zero
        self.window = window
    }

    func place(under frame: NSRect) {
        window.setFrameOrigin(NSPoint(x: frame.minX - 8, y: frame.maxY - 120))
        window.orderFrontRegardless()
    }
}

@MainActor
final class BehindClickView: NSView {
    private(set) var hits = 0

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        hits += 1
        super.mouseDown(with: event)
    }
}
