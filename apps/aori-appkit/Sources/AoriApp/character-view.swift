import AppKit
import AoriCore

@MainActor
final class CharacterView: NSView {
    var dragsWindow = false
    var clickThrough = false
    var holdMouseIgnore = false
    var clearsBackground = false {
        didSet { applyBackground() }
    }

    private let caption = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "Aori")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let visionBadge = NSTextField(labelWithString: "Vision")
    // The timer is created on the main run loop and invalidated in deinit.
    private nonisolated(unsafe) var timer: Timer?
    private var speaking = false
    private var emotion = CompanionEmotion.neutral
    private var mouthLevel = 0.0
    private var viseme = "a"
    private var sway = 0.0
    private var poseTime = 0.0
    private var blink = 0.0
    private var reduceMotion = false
    private var meshes: [VRMMesh] = []
    private var blendShapes: [VRMBlendShape] = []
    private var weights: [MorphWeight] = []
    private var loadedVertexCount = -1
    private var loadedBytes: Data?
    private var latestPixels: [UInt8] = []
    private var latestWidth = 0
    private var latestHeight = 0
    private nonisolated(unsafe) var faceScene: OpaquePointer?
    private var started = Date()
    private let avatarKind = AvatarKind.resolve(ProcessInfo.processInfo.environment["AORI_AVATAR"])
    private var loggedLayeredAvatar = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel(AccessibilityCopy.character)
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
        viseme: String,
        scene: VRMScene?,
        bytes: Data?
    ) {
        titleLabel.stringValue = presentation.title
        subtitleLabel.stringValue = presentation.subtitle
        self.speaking = speaking
        emotion = presentation.emotion
        self.mouthLevel = mouthLevel
        self.viseme = viseme
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
            latestPixels = pixels
            latestWidth = width
            latestHeight = height
            FaceRaster.draw(pixels: pixels, width: width, height: height, in: bounds)
            return
        }
        latestPixels = []
        FaceDraw.paint(meshes: meshes, weights: weights, sway: sway, bounds: bounds)
    }

    func sampleClickThrough() -> ClickThroughSample {
        let width = bounds.width >= 2 ? Int(bounds.width.rounded()) : 280
        let height = bounds.height >= 2 ? Int(bounds.height.rounded()) : 380
        let pixels = rasterPixels(time: poseTime, blink: blink, width: width, height: height) ?? []
        let cornerAlpha: UInt8 = pixels.count >= 4 ? pixels[3] : 0
        let cornerPass = ClickThrough.ignores(alpha: cornerAlpha, enabled: clickThrough)
        var opaque = false
        var index = 3
        while index < pixels.count {
            if pixels[index] > 0 {
                opaque = true
                break
            }
            index += 4
        }
        let ignores = cornerPass
        window?.ignoresMouseEvents = ignores
        return ClickThroughSample(
            corner: ClickThrough.decision(pass: cornerPass),
            body: ClickThrough.decision(pass: !opaque),
            ignoresMouse: ignores
        )
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
        visionBadge.font = .systemFont(ofSize: 12, weight: .bold)
        visionBadge.textColor = .white
        visionBadge.alignment = .center
        visionBadge.wantsLayer = true
        visionBadge.layer?.backgroundColor = NSColor.systemOrange.cgColor
        visionBadge.layer?.cornerRadius = 6
        visionBadge.isHidden = true
        visionBadge.setAccessibilityLabel("Screen vision is on")
        visionBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visionBadge)

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

            visionBadge.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            visionBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            visionBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
            visionBadge.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    func setSpeechCaption(_ text: String) {
        setAccessibilityValue(text)
        NSAccessibility.post(
            element: self,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSNumber(value: NSAccessibilityPriorityLevel.high.rawValue),
            ]
        )
    }

    func setVisionIndicator(_ visible: Bool) {
        visionBadge.isHidden = !visible
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
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        poseTime = MotionPolicy.idleTime(time: time, reduceMotion: reduceMotion)
        blink = MotionPolicy.blink(time: time, reduceMotion: reduceMotion)
        let pose = CharacterMotion.pose(time: poseTime, speaking: speaking, emotion: emotion)
        let mouth = speaking ? mouthLevel : 0
        weights = FaceDriver.morphWeights(
            blendShapes: blendShapes,
            emotion: emotion,
            mouthOpen: mouth,
            blink: blink,
            viseme: viseme
        )
        sway = self.reduceMotion ? 0 : pose.sway
        updateMousePass()
        needsDisplay = true
    }

    private func updateMousePass() {
        guard !holdMouseIgnore else {
            return
        }
        guard let window else {
            return
        }
        guard clickThrough else {
            window.ignoresMouseEvents = false
            return
        }
        let mouse = NSEvent.mouseLocation
        if !window.frame.contains(mouse) {
            window.ignoresMouseEvents = true
            return
        }
        let point = convert(window.convertPoint(fromScreen: mouse), from: nil)
        if let hit = hitTest(point), hit !== self {
            window.ignoresMouseEvents = false
            return
        }
        window.ignoresMouseEvents = ClickThrough.ignores(alpha: alpha(at: point), enabled: true)
    }

    private func alpha(at point: NSPoint) -> UInt8 {
        guard latestWidth > 1, latestHeight > 1, !latestPixels.isEmpty else {
            return 255
        }
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard x >= 0, y >= 0, x < latestWidth, y < latestHeight else {
            return 0
        }
        let rasterY = ClickThrough.rasterY(viewY: y, height: latestHeight)
        guard rasterY >= 0, rasterY < latestHeight else {
            return 0
        }
        let offset = (rasterY * latestWidth + x) * 4 + 3
        guard offset < latestPixels.count else {
            return 0
        }
        return latestPixels[offset]
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
        guard width > 1, height > 1 else {
            return nil
        }
        if avatarKind == .layered {
            return layeredPixels(time: time, blink: blink, width: width, height: height)
        }
        guard let faceScene else {
            return nil
        }
        let feelings = feelingWeights(emotion)
        let mouth = speaking ? Float(mouthLevel) : 0
        let look = LookAt.offset(time: time, reduceMotion: reduceMotion)
        return FaceRaster.render(
            scene: faceScene,
            mouth: mouth,
            blink: Float(blink),
            happy: feelings.happy,
            sad: feelings.sad,
            surprised: feelings.surprised,
            viseme: Viseme(rawValue: viseme)?.code ?? Viseme.sil.code,
            time: Float(time),
            lookX: Float(look.x),
            lookY: Float(look.y),
            width: width,
            height: height
        )
    }

    private func layeredPixels(time: Double, blink: Double, width: Int, height: Int) -> [UInt8]? {
        let preset = Viseme(rawValue: viseme) ?? .sil
        let look = LookAt.offset(time: time, reduceMotion: reduceMotion)
        let mouth = speaking ? mouthLevel : 0
        let parameters = Live2DPose.parameters(
            mouth: mouth,
            blink: blink,
            viseme: preset,
            lookX: look.x,
            lookY: look.y,
            emotion: emotion
        )
        guard let pixels = FaceRaster.renderLive2D(
            mouth: Float(parameters.mouthOpenY),
            eyeL: Float(parameters.eyeLOpen),
            eyeR: Float(parameters.eyeROpen),
            angleX: Float(parameters.angleX),
            angleY: Float(parameters.angleY),
            time: Float(time),
            width: width,
            height: height
        ) else {
            return nil
        }
        if !loggedLayeredAvatar {
            loggedLayeredAvatar = true
            let line = "aori_avatar=live2d\n"
            if let data = line.data(using: .utf8) {
                FileHandle.standardOutput.write(data)
                try? FileHandle.standardOutput.synchronize()
            }
        }
        return pixels
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
