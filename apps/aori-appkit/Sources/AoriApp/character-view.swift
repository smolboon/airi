import AppKit
import SceneKit
import AoriCore

@MainActor
final class CharacterView: NSView {
    var dragsWindow = false {
        didSet { sceneView.dragsWindow = dragsWindow }
    }

    var clearsBackground = false {
        didSet { applyBackground() }
    }

    private let sceneView = DragSceneView()
    private let caption = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "Aori")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let characterRoot = SCNNode()
    // The timer is created on the main run loop and invalidated in deinit.
    private nonisolated(unsafe) var timer: Timer?
    private var speaking = false
    private var emotion = CompanionEmotion.neutral
    private var mouthLevel = 0.0
    private var blendShapes: [VRMBlendShape] = []
    private var loadedVertexCount = -1
    private var started = Date()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        buildScene()
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
            characterRoot.childNodes.forEach { $0.removeFromParentNode() }
            characterRoot.addChildNode(VRMSceneBuilder.makeRoot(scene: scene))
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

    private func buildScene() {
        let scene = SCNScene()
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 20
        cameraNode.position = SCNVector3(0, 0.22, 1.35)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 650

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.intensity = 800
        directional.eulerAngles = SCNVector3(-0.6, 0.4, 0)

        scene.rootNode.addChildNode(characterRoot)
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(ambient)
        scene.rootNode.addChildNode(directional)

        sceneView.scene = scene
        sceneView.allowsCameraControl = false
        sceneView.autoenablesDefaultLighting = false
        sceneView.antialiasingMode = .multisampling4X
        sceneView.translatesAutoresizingMaskIntoConstraints = false
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

        sceneView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sceneView)
        addSubview(caption)

        NSLayoutConstraint.activate([
            sceneView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: trailingAnchor),
            sceneView.topAnchor.constraint(equalTo: topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: bottomAnchor),

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
        sceneView.backgroundColor = clearsBackground ? .clear : .windowBackgroundColor
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
        let weights = FaceDriver.morphWeights(
            blendShapes: blendShapes,
            emotion: emotion,
            mouthOpen: mouth,
            blink: blink
        )
        if let modelRoot = characterRoot.childNodes.first {
            VRMSceneBuilder.apply(weights: weights, to: modelRoot)
        }
        characterRoot.position = SCNVector3(Float(pose.sway), 0, 0)
    }

}

@MainActor
private final class DragSceneView: SCNView {
    var dragsWindow = false

    override func mouseDown(with event: NSEvent) {
        if dragsWindow {
            window?.performDrag(with: event)
            return
        }
        super.mouseDown(with: event)
    }
}
