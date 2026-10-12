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
    private var poseTime = 0.0
    private var blink = 0.0
    private var meshes: [VRMMesh] = []
    private var blendShapes: [VRMBlendShape] = []
    private var weights: [MorphWeight] = []
    private var loadedVertexCount = -1
    private var loadedBytes: Data?
    private nonisolated(unsafe) var faceScene: OpaquePointer?
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
        if let faceScene {
            aoriFaceFree(faceScene)
        }
    }

    func apply(
        presentation: CharacterPresentation,
        speaking: Bool,
        mouthLevel: Double,
        scene: VRMScene?,
        bytes: Data?
    ) {
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
        loadModel(bytes)
        tick()
    }

    func renderedPNG(time: Double) -> Data? {
        let width = bounds.width >= 2 ? Int(bounds.width.rounded()) : 280
        let height = bounds.height >= 2 ? Int(bounds.height.rounded()) : 380
        let frameBlink = MotionPolicy.blink(time: time, reduceMotion: false)
        guard let pixels = rasterPixels(time: time, blink: frameBlink, width: width, height: height) else {
            return nil
        }
        return FaceRaster.png(pixels: pixels, width: width, height: height)
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
        let width = Int(bounds.width.rounded())
        let height = Int(bounds.height.rounded())
        if let pixels = rasterPixels(time: poseTime, blink: blink, width: width, height: height) {
            FaceRaster.draw(pixels: pixels, width: width, height: height, in: bounds)
            return
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
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        poseTime = MotionPolicy.idleTime(time: time, reduceMotion: reduceMotion)
        blink = MotionPolicy.blink(time: time, reduceMotion: reduceMotion)
        let pose = CharacterMotion.pose(time: poseTime, speaking: speaking, emotion: emotion)
        let mouth = speaking ? mouthLevel : 0
        weights = FaceDriver.morphWeights(
            blendShapes: blendShapes,
            emotion: emotion,
            mouthOpen: mouth,
            blink: blink
        )
        sway = reduceMotion ? 0 : pose.sway
        needsDisplay = true
    }

    private func loadModel(_ bytes: Data?) {
        guard let bytes, bytes != loadedBytes else {
            return
        }
        if let faceScene {
            aoriFaceFree(faceScene)
            self.faceScene = nil
        }
        loadedBytes = bytes
        faceScene = FaceRaster.load(bytes)
    }

    private func rasterPixels(time: Double, blink: Double, width: Int, height: Int) -> [UInt8]? {
        guard let faceScene, width > 1, height > 1 else {
            return nil
        }
        let feelings = feelingWeights(emotion)
        let mouth = speaking ? Float(mouthLevel) : 0
        return FaceRaster.render(
            scene: faceScene,
            mouth: mouth,
            blink: Float(blink),
            happy: feelings.happy,
            sad: feelings.sad,
            surprised: feelings.surprised,
            time: Float(time),
            width: width,
            height: height
        )
    }

    private func feelingWeights(_ emotion: CompanionEmotion) -> (happy: Float, sad: Float, surprised: Float) {
        switch emotion {
        case .happy:
            return (1, 0, 0)
        case .sad:
            return (0, 1, 0)
        case .surprised:
            return (0, 0, 1)
        case .neutral:
            return (0, 0, 0)
        }
    }
}
