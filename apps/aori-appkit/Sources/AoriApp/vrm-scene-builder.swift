import AoriCore
import AppKit
import SceneKit

enum VRMSceneBuilder {
    static func makeRoot(scene: VRMScene) -> SCNNode {
        let root = SCNNode()
        for mesh in scene.meshes {
            root.addChildNode(makeNode(mesh: mesh))
        }
        return root
    }

    static func apply(weights: [MorphWeight], to root: SCNNode) {
        for child in root.childNodes {
            guard let morpher = child.morpher else {
                continue
            }
            for index in 0..<morpher.targets.count {
                morpher.setWeight(0, forTargetAt: index)
            }
        }
        for weight in weights {
            guard root.childNodes.indices.contains(weight.mesh) else {
                continue
            }
            let node = root.childNodes[weight.mesh]
            guard let morpher = node.morpher, weight.morph < morpher.targets.count else {
                continue
            }
            morpher.setWeight(CGFloat(weight.weight), forTargetAt: weight.morph)
        }
    }

    private static func makeNode(mesh: VRMMesh) -> SCNNode {
        let node = SCNNode(geometry: geometry(mesh: mesh, positions: mesh.positions))
        let targets = mesh.morphs.map { morph in
            let positions = zip(mesh.positions, morph.positionDeltas).map { base, delta in
                base + delta
            }
            return geometry(mesh: mesh, positions: positions)
        }
        if !targets.isEmpty {
            let morpher = SCNMorpher()
            morpher.targets = targets
            node.morpher = morpher
        }
        return node
    }

    private static func geometry(mesh: VRMMesh, positions: [VRMVec3]) -> SCNGeometry {
        let vertices = positions.map { SCNVector3($0.x, $0.y, $0.z) }
        let normals = mesh.normals.map { SCNVector3($0.x, $0.y, $0.z) }
        let sources = [
            SCNGeometrySource(vertices: vertices),
            SCNGeometrySource(normals: normals),
        ]
        let indexData = mesh.indices.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: mesh.indices.count / 3,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        let geometry = SCNGeometry(sources: sources, elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(
            red: CGFloat(mesh.color.red),
            green: CGFloat(mesh.color.green),
            blue: CGFloat(mesh.color.blue),
            alpha: CGFloat(mesh.color.alpha)
        )
        material.lightingModel = .blinn
        geometry.materials = [material]
        return geometry
    }
}
