import AppKit
import AoriCore

enum AccentPalette {
    static var fill: NSColor {
        NSColor(
            srgbRed: CGFloat(AccentColor.red) / 255,
            green: CGFloat(AccentColor.green) / 255,
            blue: CGFloat(AccentColor.blue) / 255,
            alpha: 1
        )
    }

    static var ink: NSColor {
        NSColor(
            srgbRed: CGFloat(AccentColor.foregroundRed) / 255,
            green: CGFloat(AccentColor.foregroundGreen) / 255,
            blue: CGFloat(AccentColor.foregroundBlue) / 255,
            alpha: 1
        )
    }

    static func apply(to button: NSButton) {
        button.bezelColor = fill
        button.contentTintColor = ink
        let font = button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: ink,
                .font: font,
            ]
        )
    }
}

/// Draws the accent wash. The timer stops when the window is hidden or Reduce Motion is on.
final class AccentWashView: NSView {
    private var pixels: [UInt8] = []
    private var pixelWidth = 0
    private var pixelHeight = 0
    private var started = Date()
    private var timer: Timer?
    private var reduceMotion = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        started = Date()
        observeMotion()
        render(time: 0, advances: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        timer?.invalidate()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(visibilityChanged),
                name: NSWindow.didChangeOcclusionStateNotification,
                object: window
            )
        }
        updateTimer()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard pixelWidth > 1, pixelHeight > 1, !pixels.isEmpty else {
            NSColor(srgbRed: 20 / 255, green: 20 / 255, blue: 20 / 255, alpha: 1).setFill()
            bounds.fill()
            return
        }
        guard let image = FaceRaster.image(pixels: pixels, width: pixelWidth, height: pixelHeight) else {
            return
        }
        let painted = NSImage(cgImage: image, size: NSSize(width: pixelWidth, height: pixelHeight))
        painted.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
    }

    private func observeMotion() {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(motionChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    @objc private func motionChanged() {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        updateTimer()
    }

    @objc private func visibilityChanged() {
        updateTimer()
    }

    private func windowIsVisible() -> Bool {
        guard let window else {
            return false
        }
        if window.isMiniaturized {
            return false
        }
        return window.occlusionState.contains(.visible)
    }

    private func updateTimer() {
        let visible = windowIsVisible()
        let frame = AccentField.frame(
            width: 2,
            height: 2,
            time: Date().timeIntervalSince(started),
            reduceMotion: reduceMotion,
            visible: visible
        )
        if frame.advances {
            startTimer()
        } else {
            timer?.invalidate()
            timer = nil
            render(time: 0, advances: false)
        }
    }

    private func startTimer() {
        guard timer == nil else {
            return
        }
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    private func tick() {
        let visible = windowIsVisible()
        render(time: Date().timeIntervalSince(started), advances: visible && !reduceMotion)
        if !visible || reduceMotion {
            timer?.invalidate()
            timer = nil
        }
    }

    private func render(time: Double, advances: Bool) {
        let width = 160
        let height = 90
        let frame = AccentField.frame(
            width: width,
            height: height,
            time: time,
            reduceMotion: !advances,
            visible: true
        )
        pixels = frame.pixels
        pixelWidth = frame.width
        pixelHeight = frame.height
        needsDisplay = true
    }
}
