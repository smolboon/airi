import AppKit
import AoriCore

@MainActor
final class CharacterView: NSView {
    var dragsWindow = false
    var clearsBackground = false {
        didSet { applyBackground() }
    }

    private let caption = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "Aori")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    // The timer is created on the main run loop and invalidated in deinit.
    private nonisolated(unsafe) var timer: Timer?
    private var speaking = false
    private var emotion = CompanionEmotion.neutral
    private var mouthLevel = 0.0
    private var sway = 0.0
    private var meshes: [VRMMesh] = []
    private var blendShapes: [VRMBlendShape] = []
    private var weights: [MorphWeight] = []
    private var loadedVertexCount = -1
    private var started = Date()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        buildChrome()
        applyBackground()
        startTimer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        timer?.invalidate()
    }

    func apply(presentation: CharacterPresentation, speaking: Bool, mouthLevel: Double, scene: VRMScene?) {
        titleLabel.stringValue = presentation.title
        subtitleLabel.stringValue = presentation.subtitle
        self.speaking = speaking
        emotion = presentation.emotion
        self.mouthLevel = mouthLevel
        if let scene, scene.vertexCount != loadedVertexCount {
            meshes = scene.meshes
            blendShapes = scene.blendShapes
            loadedVertexCount = scene.vertexCount
        }
        tick()
    }

    override func mouseDown(with event: NSEvent) {
        if dragsWindow {
            window?.performDrag(with: event)
            return
        }
        super.mouseDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if !clearsBackground {
            NSColor.windowBackgroundColor.setFill()
            bounds.fill()
        }
        FaceDraw.paint(meshes: meshes, weights: weights, sway: sway, bounds: bounds)
    }

    private func buildChrome() {
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 3
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        caption.material = .hudWindow
        caption.blendingMode = .withinWindow
        caption.state = .active
        caption.wantsLayer = true
        caption.layer?.cornerRadius = 10
        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.addSubview(titleLabel)
        caption.addSubview(subtitleLabel)
        addSubview(caption)

        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            caption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            caption.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            titleLabel.leadingAnchor.constraint(equalTo: caption.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: caption.trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: caption.topAnchor, constant: 8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(equalTo: caption.bottomAnchor, constant: -8),
        ])
    }

    private func applyBackground() {
        layer?.backgroundColor = clearsBackground
            ? NSColor.clear.cgColor
            : NSColor.windowBackgroundColor.cgColor
        needsDisplay = true
    }

    private func startTimer() {
        guard timer == nil else {
            return
        }
        started = Date()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let time = Date().timeIntervalSince(started)
        let pose = CharacterMotion.pose(time: time, speaking: speaking, emotion: emotion)
        let blink = abs(time.truncatingRemainder(dividingBy: 3.2) - 0.1) < 0.08 ? 1.0 : 0.0
        let mouth = speaking ? mouthLevel : 0
        weights = FaceDriver.morphWeights(
            blendShapes: blendShapes,
            emotion: emotion,
            mouthOpen: mouth,
            blink: blink
        )
        sway = pose.sway
        needsDisplay = true
    }
}
