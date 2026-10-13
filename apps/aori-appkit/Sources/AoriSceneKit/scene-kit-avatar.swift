import AppKit
import AoriCore
import ImageIO
import Metal
import SceneKit
import UniformTypeIdentifiers

enum SceneKitAvatar {
    static let frameWidth = 280
    static let frameHeight = 380

    static func writePNG(scene: VRMScene, pose: VRMAvatarPose, path: String) -> Bool {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return false
        }
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = makeScene(vrm: scene, pose: pose)
        renderer.pointOfView = renderer.scene?.rootNode.childNode(withName: "camera", recursively: true)
        let size = CGSize(width: frameWidth, height: frameHeight)
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        guard var pixels = rgba(from: image, width: frameWidth, height: frameHeight) else {
            return false
        }
        clearGreen(&pixels)
        return writePNG(pixels: pixels, width: frameWidth, height: frameHeight, path: path)
    }

    static func makeScene(vrm: VRMScene, pose: VRMAvatarPose) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
        let weights = weightGrid(vrm: vrm, pose: pose)
        let head = SCNNode()
        head.name = "headGroup"
        head.eulerAngles = SCNVector3(pose.pitch, pose.yaw, 0)
        for (index, mesh) in vrm.meshes.enumerated() {
            let node = SCNNode(geometry: geometry(mesh: mesh, morphIndex: nil))
            node.name = mesh.name
            apply(weights: index < weights.count ? weights[index] : [], mesh: mesh, node: node)
            head.addChildNode(node)
        }
        scene.rootNode.addChildNode(head)

        let camera = SCNNode()
        camera.name = "camera"
        camera.camera = SCNCamera()
        let frame = frame(of: vrm)
        camera.position = SCNVector3(frame.x, frame.y, frame.distance)
        camera.look(at: SCNVector3(frame.x, frame.lookY, frame.z))
        scene.rootNode.addChildNode(camera)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 900
        key.eulerAngles = SCNVector3(-0.5, 0.3, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 500
        scene.rootNode.addChildNode(fill)
        return scene
    }

    private static func frame(of vrm: VRMScene) -> (x: Float, y: Float, z: Float, lookY: Float, distance: Float) {
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        for mesh in vrm.meshes {
            for position in mesh.positions {
                minX = min(minX, position.x)
                maxX = max(maxX, position.x)
                minY = min(minY, position.y)
                maxY = max(maxY, position.y)
                minZ = min(minZ, position.z)
                maxZ = max(maxZ, position.z)
            }
        }
        if minY > maxY {
            return (0, 0.15, 0, 0.1, 1.4)
        }
        let height = max(0.2, maxY - minY)
        let lookY = maxY - height * 0.12
        let span = max(height * 0.35, maxX - minX)
        let distance = max(0.45, maxZ + span * 0.9)
        return ((minX + maxX) * 0.5, lookY, (minZ + maxZ) * 0.5, lookY, distance)
    }

    private static func weightGrid(vrm: VRMScene, pose: VRMAvatarPose) -> [[CGFloat]] {
        var grid = vrm.meshes.map { mesh in
            Array(repeating: CGFloat(0), count: mesh.morphs.count)
        }
        for weight in pose.weights(in: vrm) {
            guard vrm.meshes.indices.contains(weight.mesh) else {
                continue
            }
            guard vrm.meshes[weight.mesh].morphs.indices.contains(weight.morph) else {
                continue
            }
            let next = grid[weight.mesh][weight.morph] + CGFloat(weight.weight)
            grid[weight.mesh][weight.morph] = min(1, max(0, next))
        }
        return grid
    }

    private static func apply(weights: [CGFloat], mesh: VRMMesh, node: SCNNode) {
        guard !mesh.morphs.isEmpty else {
            return
        }
        let morpher = SCNMorpher()
        morpher.targets = mesh.morphs.indices.map { geometry(mesh: mesh, morphIndex: $0) }
        node.morpher = morpher
        for (index, weight) in weights.enumerated() where index < morpher.targets.count {
            morpher.setWeight(weight, forTargetAt: index)
        }
    }

    private static func geometry(mesh: VRMMesh, morphIndex: Int?) -> SCNGeometry {
        let positions = deformed(mesh: mesh, morphIndex: morphIndex)
        let vectors = positions.map { SCNVector3($0.x, $0.y, $0.z) }
        let normalCount = min(mesh.normals.count, vectors.count)
        let normals = (0..<vectors.count).map { index -> SCNVector3 in
            if index < normalCount {
                let normal = mesh.normals[index]
                return SCNVector3(normal.x, normal.y, normal.z)
            }
            return SCNVector3(0, 0, 1)
        }
        var sources = [
            SCNGeometrySource(vertices: vectors),
            SCNGeometrySource(normals: normals),
        ]
        if mesh.uvs.count == vectors.count {
            let coordinates = mesh.uvs.map { CGPoint(x: CGFloat($0.u), y: CGFloat(1 - $0.v)) }
            sources.append(SCNGeometrySource(textureCoordinates: coordinates))
        }
        let indexData = mesh.indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: mesh.indices.count / 3,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        let geometry = SCNGeometry(sources: sources, elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .blinn
        if let image = NSImage(data: mesh.texturePNG), !mesh.texturePNG.isEmpty {
            material.diffuse.contents = image
        } else {
            material.diffuse.contents = NSColor(
                srgbRed: CGFloat(mesh.color.red),
                green: CGFloat(mesh.color.green),
                blue: CGFloat(mesh.color.blue),
                alpha: CGFloat(mesh.color.alpha)
            )
        }
        material.locksAmbientWithDiffuse = true
        material.isDoubleSided = true
        geometry.materials = [material]
        return geometry
    }

    private static func deformed(mesh: VRMMesh, morphIndex: Int?) -> [VRMVec3] {
        guard let morphIndex, mesh.morphs.indices.contains(morphIndex) else {
            return mesh.positions
        }
        let deltas = mesh.morphs[morphIndex].positionDeltas
        return mesh.positions.enumerated().map { index, position in
            guard index < deltas.count else {
                return position
            }
            return position + deltas[index]
        }
    }

    private static func rgba(from image: NSImage, width: Int, height: Int) -> [UInt8]? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        guard let raw = rep.bitmapData else {
            return nil
        }
        return Array(UnsafeBufferPointer(start: raw, count: width * height * 4))
    }

    private static func clearGreen(_ pixels: inout [UInt8]) {
        var index = 0
        while index + 3 < pixels.count {
            let red = Int(pixels[index])
            let green = Int(pixels[index + 1])
            let blue = Int(pixels[index + 2])
            if green > 180 && green > red + 40 && green > blue + 40 {
                pixels[index] = 0
                pixels[index + 1] = 0
                pixels[index + 2] = 0
                pixels[index + 3] = 0
            }
            index += 4
        }
    }

    private static func writePNG(pixels: [UInt8], width: Int, height: Int, path: String) -> Bool {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else {
            return false
        }
        let alpha = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: alpha),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return false
        }
        let url = URL(fileURLWithPath: path) as CFURL
        guard let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
}
