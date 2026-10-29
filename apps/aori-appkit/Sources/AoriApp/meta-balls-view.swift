import AppKit
import AoriCore

/// Core Graphics port of the SoloLVL canvas. Twelve radial gradients per frame.
/// The timer stops when the window is hidden or Reduce Motion is on.
final class MetaBallsView: NSView {
    private var field: MetaBalls?
    private var timer: Timer?
    private var reduceMotion = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        observeMotion()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        timer?.invalidate()
    }

    override func layout() {
        super.layout()
        guard bounds.width > 2, bounds.height > 2 else {
            return
        }
        if field == nil {
            field = MetaBalls(width: bounds.width, height: bounds.height, seed: 0x5010_17)
        } else {
            field?.resize(width: bounds.width, height: bounds.height)
        }
        updateTimer()
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
        NSColor.black.setFill()
        bounds.fill()
        guard let field, let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        for blob in field.blobs {
            let center = NSPoint(x: blob.x, y: blob.y)
            drawGlow(blob, center: center, context: context)
            drawCore(blob, center: center, context: context)
        }
    }

    private func drawGlow(_ blob: MetaBalls.Blob, center: NSPoint, context: CGContext) {
        let glow = NSColor(
            srgbRed: CGFloat(AccentColor.red) / 255,
            green: CGFloat(AccentColor.green) / 255,
            blue: CGFloat(AccentColor.blue) / 255,
            alpha: CGFloat(MetaBalls.glowHexAlpha) / 255
        )
        let clear = NSColor(
            srgbRed: CGFloat(AccentColor.red) / 255,
            green: CGFloat(AccentColor.green) / 255,
            blue: CGFloat(AccentColor.blue) / 255,
            alpha: 0
        )
        drawRadial(
            from: glow,
            to: clear,
            fade: MetaBalls.glowFade,
            radius: blob.radius,
            alpha: MetaBalls.glowGlobalAlpha,
            center: center,
            context: context
        )
    }

    private func drawCore(_ blob: MetaBalls.Blob, center: NSPoint, context: CGContext) {
        drawRadial(
            from: AccentPalette.fill,
            to: NSColor(
                srgbRed: CGFloat(AccentColor.red) / 255,
                green: CGFloat(AccentColor.green) / 255,
                blue: CGFloat(AccentColor.blue) / 255,
                alpha: 0
            ),
            fade: 1,
            radius: blob.radius * MetaBalls.coreRadiusScale,
            alpha: MetaBalls.coreGlobalAlpha,
            center: center,
            context: context
        )
    }

    private func drawRadial(
        from: NSColor,
        to: NSColor,
        fade: Double,
        radius: Double,
        alpha: Double,
        center: NSPoint,
        context: CGContext
    ) {
        var locations = [CGFloat(0), CGFloat(fade)]
        guard let gradient = NSGradient(
            colors: [from, to],
            atLocations: &locations,
            colorSpace: .sRGB
        ) else {
            return
        }
        context.saveGState()
        context.setAlpha(CGFloat(alpha))
        gradient.draw(
            fromCenter: center,
            radius: 0,
            toCenter: center,
            radius: CGFloat(radius),
            options: []
        )
        context.restoreGState()
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
        let advances = windowIsVisible() && !reduceMotion
        if advances {
            startTimer()
        } else {
            timer?.invalidate()
            timer = nil
            needsDisplay = true
        }
    }

    private func startTimer() {
        guard timer == nil else {
            return
        }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let advances = windowIsVisible() && !reduceMotion
        if advances {
            field?.step(reduceMotion: false, visible: true)
            needsDisplay = true
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
}
