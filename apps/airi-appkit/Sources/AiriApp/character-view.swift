import AppKit
import SceneKit
import AiriCore

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
    private let titleLabel = NSTextField(labelWithString: "AIRI")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let mouth: SCNNode
    // The timer is created on the main run loop and invalidated in deinit.
    private nonisolated(unsafe) var timer: Timer?
    private var speaking = false
    private var started = Date()

    override init(frame frameRect: NSRect) {
        let mouthGeometry = SCNBox(width: 0.12, height: 0.02, length: 0.04, chamferRadius: 0.01)
        mouthGeometry.firstMaterial = Self.material(.systemRed)
        mouth = SCNNode(geometry: mouthGeometry)
        super.init(frame: frameRect)
        wantsLayer = true
        buildScene()
        buildChrome()
        applyBackground()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        timer?.invalidate()
    }

    func apply(presentation: CharacterPresentation, speaking: Bool) {
        titleLabel.stringValue = presentation.title
        subtitleLabel.stringValue = presentation.subtitle
        self.speaking = speaking
        if speaking {
            startTimer()
        } else {
            stopTimer()
            setMouth(presentation.mouthOpen)
        }
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
        let head = SCNNode(geometry: SCNSphere(radius: 0.28))
        head.geometry?.firstMaterial = Self.material(NSColor(calibratedRed: 0.96, green: 0.78, blue: 0.74, alpha: 1))
        head.position = SCNVector3(0, 0.55, 0)

        let hair = SCNNode(geometry: SCNSphere(radius: 0.30))
        hair.geometry?.firstMaterial = Self.material(NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.28, alpha: 1))
        hair.position = SCNVector3(0, 0.12, -0.02)
        hair.scale = SCNVector3(1, 0.72, 1)
        head.addChildNode(hair)

        let leftEye = eyeNode(x: -0.09)
        let rightEye = eyeNode(x: 0.09)
        head.addChildNode(leftEye)
        head.addChildNode(rightEye)

        mouth.position = SCNVector3(0, -0.08, 0.24)
        head.addChildNode(mouth)

        let body = SCNNode(geometry: SCNCapsule(capRadius: 0.22, height: 0.72))
        body.geometry?.firstMaterial = Self.material(NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.78, alpha: 1))
        body.position = SCNVector3(0, -0.15, 0)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 20
        cameraNode.position = SCNVector3(0, 0.45, 2.6)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 650

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.intensity = 800
        directional.eulerAngles = SCNVector3(-0.6, 0.4, 0)

        scene.rootNode.addChildNode(head)
        scene.rootNode.addChildNode(body)
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

    private func eyeNode(x: Float) -> SCNNode {
        let eye = SCNNode(geometry: SCNSphere(radius: 0.035))
        eye.geometry?.firstMaterial = Self.material(.black)
        eye.position = SCNVector3(x, 0.04, 0.24)
        return eye
    }

    private func setMouth(_ amount: Double) {
        let scale = max(0.05, amount)
        mouth.scale = SCNVector3(1, Float(scale) * 8, 1)
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
        setMouth(CharacterMotion.mouthOpen(time: time, speaking: speaking))
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private static func material(_ color: NSColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .blinn
        return material
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
