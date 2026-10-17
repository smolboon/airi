import Foundation

public struct VRMVec3: Equatable, Sendable {
    public var x: Float
    public var y: Float
    public var z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static func + (lhs: VRMVec3, rhs: VRMVec3) -> VRMVec3 {
        VRMVec3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
}

public struct VRMVec2: Equatable, Sendable {
    public var u: Float
    public var v: Float

    public init(u: Float, v: Float) {
        self.u = u
        self.v = v
    }
}

public struct VRMColor: Equatable, Sendable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float

    public init(red: Float, green: Float, blue: Float, alpha: Float) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let skin = VRMColor(red: 0.96, green: 0.78, blue: 0.74, alpha: 1)
}

public struct VRMMorph: Equatable, Sendable {
    public var name: String
    public var positionDeltas: [VRMVec3]

    public init(name: String, positionDeltas: [VRMVec3]) {
        self.name = name
        self.positionDeltas = positionDeltas
    }
}

public struct VRMMesh: Equatable, Sendable {
    public var name: String
    public var positions: [VRMVec3]
    public var normals: [VRMVec3]
    public var indices: [UInt32]
    public var color: VRMColor
    public var morphs: [VRMMorph]
    public var uvs: [VRMVec2]
    public var texturePNG: Data

    public init(
        name: String,
        positions: [VRMVec3],
        normals: [VRMVec3],
        indices: [UInt32],
        color: VRMColor,
        morphs: [VRMMorph],
        uvs: [VRMVec2] = [],
        texturePNG: Data = Data()
    ) {
        self.name = name
        self.positions = positions
        self.normals = normals
        self.indices = indices
        self.color = color
        self.morphs = morphs
        self.uvs = uvs
        self.texturePNG = texturePNG
    }
}

public struct VRMBlendBind: Equatable, Sendable {
    public var mesh: Int
    public var morph: Int
    public var weight: Double

    public init(mesh: Int, morph: Int, weight: Double) {
        self.mesh = mesh
        self.morph = morph
        self.weight = weight
    }
}

public struct VRMBlendShape: Equatable, Sendable {
    public var name: String
    public var preset: String
    public var binds: [VRMBlendBind]

    public init(name: String, preset: String, binds: [VRMBlendBind]) {
        self.name = name
        self.preset = preset
        self.binds = binds
    }
}

public struct VRMScene: Equatable, Sendable {
    public var document: VRMDocument
    public var meshes: [VRMMesh]
    public var blendShapes: [VRMBlendShape]

    public init(document: VRMDocument, meshes: [VRMMesh], blendShapes: [VRMBlendShape]) {
        self.document = document
        self.meshes = meshes
        self.blendShapes = blendShapes
    }

    public var vertexCount: Int {
        meshes.reduce(0) { $0 + $1.positions.count }
    }
}

public enum VRMSceneError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingBinary
    case badAccessor(String)

    public var description: String {
        switch self {
        case .missingBinary:
            return "The VRM file has no binary chunk."
        case .badAccessor(let message):
            return "The VRM mesh data is not readable. \(message)"
        }
    }
}

public struct MorphWeight: Equatable, Sendable {
    public var mesh: Int
    public var morph: Int
    public var weight: Double

    public init(mesh: Int, morph: Int, weight: Double) {
        self.mesh = mesh
        self.morph = morph
        self.weight = weight
    }
}

public enum SpeechLevel {
    /// Scales the root-mean-square of float samples into a mouth weight from 0 to 1.
    public static func mouthOpen(samples: [Float]) -> Double {
        guard !samples.isEmpty else {
            return 0
        }
        var sum = 0.0
        for sample in samples {
            let value = Double(sample)
            sum += value * value
        }
        let rms = (sum / Double(samples.count)).squareRoot()
        return min(1, max(0, rms * 8))
    }
}

public enum FaceDriver {
    /// Maps an emotion and a mouth level onto VRM blend-shape binds.
    public static func morphWeights(
        blendShapes: [VRMBlendShape],
        emotion: CompanionEmotion,
        mouthOpen: Double,
        blink: Double,
        viseme: String = "a"
    ) -> [MorphWeight] {
        var weights: [MorphWeight] = []
        for shape in blendShapes {
            let amount = amount(for: shape, emotion: emotion, mouthOpen: mouthOpen, blink: blink, viseme: viseme)
            guard amount > 0 else {
                continue
            }
            for bind in shape.binds {
                let scaled = amount * min(1, max(0, bind.weight / 100))
                weights.append(MorphWeight(mesh: bind.mesh, morph: bind.morph, weight: scaled))
            }
        }
        return weights
    }

    private static func amount(
        for shape: VRMBlendShape,
        emotion: CompanionEmotion,
        mouthOpen: Double,
        blink: Double,
        viseme: String
    ) -> Double {
        let names = [shape.preset.lowercased(), shape.name.lowercased()]
        if names.contains(where: { isVisemeName($0, viseme: viseme) }) {
            if viseme.lowercased() == "pp" {
                return 1
            }
            return min(1, max(0, mouthOpen))
        }
        if names.contains(where: isBlinkName) {
            return min(1, max(0, blink))
        }
        switch emotion {
        case .happy:
            return names.contains(where: isHappyName) ? 1 : 0
        case .sad:
            return names.contains(where: isSadName) ? 1 : 0
        case .surprised:
            return names.contains(where: isSurprisedName) ? 1 : 0
        case .neutral:
            return 0
        }
    }

    private static func isVisemeName(_ name: String, viseme: String) -> Bool {
        switch viseme.lowercased() {
        case "a", "aa", "ah":
            return name == "a" || name == "aa" || name == "ah"
        case "i", "ih":
            return name == "i" || name == "ih"
        case "u", "ou":
            return name == "u" || name == "ou"
        case "e", "ee":
            return name == "e" || name == "ee"
        case "o", "oh":
            return name == "o" || name == "oh"
        case "pp":
            return name == "pp"
        default:
            return false
        }
    }

    private static func isBlinkName(_ name: String) -> Bool {
        name == "blink" || name == "blink_l" || name == "blink_r"
    }

    private static func isHappyName(_ name: String) -> Bool {
        name == "joy" || name == "happy" || name == "fun"
    }

    private static func isSadName(_ name: String) -> Bool {
        name == "sorrow" || name == "sad"
    }

    private static func isSurprisedName(_ name: String) -> Bool {
        name == "surprised" || name == "surprise"
    }
}

public enum VRMSceneReader {
    public static func read(_ data: Data) throws -> VRMScene {
        let file = try GLBFileReader.read(data)
        let document = VRMDocumentReader.readDocument(file)
        guard !file.bin.isEmpty || (file.json["meshes"]?.arrayCount ?? 0) == 0 else {
            throw VRMSceneError.missingBinary
        }
        let meshes = try readMeshes(json: file.json, bin: file.bin)
        let shapes = readBlendShapes(json: file.json, meshes: meshes)
        return VRMScene(document: document, meshes: meshes, blendShapes: shapes)
    }

    private static func readMeshes(json: JSONValue, bin: Data) throws -> [VRMMesh] {
        let materials = json["materials"]?.array ?? []
        return try (json["meshes"]?.array ?? []).enumerated().map { index, mesh in
            let primitive = mesh["primitives"]?[0]
            let attributes = primitive?["attributes"]
            let positionIndex = attributes?["POSITION"]?.int
            let normalIndex = attributes?["NORMAL"]?.int
            let indexIndex = primitive?["indices"]?.int
            guard let positionIndex else {
                throw VRMSceneError.badAccessor("Mesh \(index) has no positions.")
            }
            let positions = try readVec3(json: json, bin: bin, accessor: positionIndex)
            let normals: [VRMVec3]
            if let normalIndex {
                normals = try readVec3(json: json, bin: bin, accessor: normalIndex)
            } else {
                normals = positions
            }
            let indices: [UInt32]
            if let indexIndex {
                indices = try readIndices(json: json, bin: bin, accessor: indexIndex)
            } else {
                indices = Array(UInt32(0)..<UInt32(positions.count))
            }
            let materialIndex = primitive?["material"]?.int ?? 0
            let material = materials.indices.contains(materialIndex) ? materials[materialIndex] : nil
            let color = color(of: material)
            let uvs: [VRMVec2]
            if let uvIndex = attributes?["TEXCOORD_0"]?.int {
                uvs = (try? readVec2(json: json, bin: bin, accessor: uvIndex)) ?? []
            } else {
                uvs = []
            }
            let texturePNG = texturePNG(json: json, bin: bin, material: material)
            let targetNames = mesh["extras"]?["targetNames"]?.array.compactMap(\.string) ?? []
            let targets = primitive?["targets"]?.array ?? []
            var morphs: [VRMMorph] = []
            for (targetIndex, target) in targets.enumerated() {
                guard let accessor = target["POSITION"]?.int else {
                    continue
                }
                let deltas = try readVec3(json: json, bin: bin, accessor: accessor)
                let name = targetIndex < targetNames.count ? targetNames[targetIndex] : "morph\(targetIndex)"
                morphs.append(VRMMorph(name: name, positionDeltas: deltas))
            }
            let name = mesh["name"]?.string ?? "mesh\(index)"
            return VRMMesh(
                name: name,
                positions: positions,
                normals: normals,
                indices: indices,
                color: color,
                morphs: morphs,
                uvs: uvs,
                texturePNG: texturePNG
            )
        }
    }

    private static func readBlendShapes(json: JSONValue, meshes: [VRMMesh]) -> [VRMBlendShape] {
        let groups = json["extensions"]?["VRM"]?["blendShapeMaster"]?["blendShapeGroups"]?.array ?? []
        if !groups.isEmpty {
            return groups.map { group in
                let binds = (group["binds"]?.array ?? []).compactMap { bind -> VRMBlendBind? in
                    guard let mesh = bind["mesh"]?.int, let morph = bind["index"]?.int else {
                        return nil
                    }
                    return VRMBlendBind(mesh: mesh, morph: morph, weight: bind["weight"]?.double ?? 100)
                }
                return VRMBlendShape(
                    name: group["name"]?.string ?? "",
                    preset: group["presetName"]?.string ?? "",
                    binds: binds
                )
            }
        }
        var shapes: [VRMBlendShape] = []
        for (meshIndex, mesh) in meshes.enumerated() {
            for (morphIndex, morph) in mesh.morphs.enumerated() {
                shapes.append(
                    VRMBlendShape(
                        name: morph.name,
                        preset: morph.name,
                        binds: [VRMBlendBind(mesh: meshIndex, morph: morphIndex, weight: 100)]
                    )
                )
            }
        }
        return shapes
    }

    private static func color(of material: JSONValue?) -> VRMColor {
        let factor = material?["pbrMetallicRoughness"]?["baseColorFactor"]?.array ?? []
        guard factor.count >= 3 else {
            return .skin
        }
        return VRMColor(
            red: Float(factor[0].double ?? 1),
            green: Float(factor[1].double ?? 1),
            blue: Float(factor[2].double ?? 1),
            alpha: Float(factor.count > 3 ? (factor[3].double ?? 1) : 1)
        )
    }

    private static func texturePNG(json: JSONValue, bin: Data, material: JSONValue?) -> Data {
        guard let textureIndex = material?["pbrMetallicRoughness"]?["baseColorTexture"]?["index"]?.int else {
            return Data()
        }
        let textures = json["textures"]?.array ?? []
        guard textures.indices.contains(textureIndex), let source = textures[textureIndex]["source"]?.int else {
            return Data()
        }
        let images = json["images"]?.array ?? []
        guard images.indices.contains(source), let viewIndex = images[source]["bufferView"]?.int else {
            return Data()
        }
        let views = json["bufferViews"]?.array ?? []
        guard views.indices.contains(viewIndex) else {
            return Data()
        }
        let offset = views[viewIndex]["byteOffset"]?.int ?? 0
        let length = views[viewIndex]["byteLength"]?.int ?? 0
        guard length > 8, offset >= 0, offset + length <= bin.count else {
            return Data()
        }
        return bin.subdata(in: offset..<(offset + length))
    }

    private static func readVec2(json: JSONValue, bin: Data, accessor: Int) throws -> [VRMVec2] {
        let floats = try readFloats(json: json, bin: bin, accessor: accessor, components: 2)
        var vectors: [VRMVec2] = []
        vectors.reserveCapacity(floats.count / 2)
        var index = 0
        while index + 1 < floats.count {
            vectors.append(VRMVec2(u: floats[index], v: floats[index + 1]))
            index += 2
        }
        return vectors
    }

    private static func readVec3(json: JSONValue, bin: Data, accessor: Int) throws -> [VRMVec3] {
        let floats = try readFloats(json: json, bin: bin, accessor: accessor, components: 3)
        var vectors: [VRMVec3] = []
        vectors.reserveCapacity(floats.count / 3)
        var index = 0
        while index + 2 < floats.count {
            vectors.append(VRMVec3(x: floats[index], y: floats[index + 1], z: floats[index + 2]))
            index += 3
        }
        return vectors
    }

    private static func readFloats(json: JSONValue, bin: Data, accessor: Int, components: Int) throws -> [Float] {
        let info = try accessorInfo(json: json, accessor: accessor)
        guard info.componentType == 5126 else {
            throw VRMSceneError.badAccessor("Accessor \(accessor) is not a float buffer.")
        }
        var values: [Float] = []
        values.reserveCapacity(info.count * components)
        for item in 0..<info.count {
            let start = info.offset + item * info.stride
            for component in 0..<components {
                let byte = start + component * 4
                guard byte + 4 <= bin.count else {
                    throw VRMSceneError.badAccessor("Accessor \(accessor) is past the binary chunk.")
                }
                values.append(readFloat(bin, offset: byte))
            }
        }
        return values
    }

    private static func readIndices(json: JSONValue, bin: Data, accessor: Int) throws -> [UInt32] {
        let info = try accessorInfo(json: json, accessor: accessor)
        var values: [UInt32] = []
        values.reserveCapacity(info.count)
        for item in 0..<info.count {
            let start = info.offset + item * info.stride
            switch info.componentType {
            case 5123:
                guard start + 2 <= bin.count else {
                    throw VRMSceneError.badAccessor("Index accessor \(accessor) is past the binary chunk.")
                }
                let low = UInt32(bin[bin.startIndex + start])
                let high = UInt32(bin[bin.startIndex + start + 1])
                values.append(low | (high << 8))
            case 5125:
                guard start + 4 <= bin.count else {
                    throw VRMSceneError.badAccessor("Index accessor \(accessor) is past the binary chunk.")
                }
                values.append(readUInt32(bin, offset: start))
            default:
                throw VRMSceneError.badAccessor("Index accessor \(accessor) uses an unsupported type.")
            }
        }
        return values
    }

    private static func accessorInfo(json: JSONValue, accessor: Int) throws -> (offset: Int, count: Int, stride: Int, componentType: Int) {
        let accessors = json["accessors"]?.array ?? []
        let views = json["bufferViews"]?.array ?? []
        guard accessors.indices.contains(accessor) else {
            throw VRMSceneError.badAccessor("Accessor \(accessor) is missing.")
        }
        let item = accessors[accessor]
        let viewIndex = item["bufferView"]?.int ?? 0
        guard views.indices.contains(viewIndex) else {
            throw VRMSceneError.badAccessor("Buffer view \(viewIndex) is missing.")
        }
        let view = views[viewIndex]
        let componentType = item["componentType"]?.int ?? 0
        let count = item["count"]?.int ?? 0
        let componentSize = componentType == 5123 ? 2 : 4
        let components = componentCount(item["type"]?.string ?? "SCALAR")
        let defaultStride = componentSize * components
        let stride = view["byteStride"]?.int ?? defaultStride
        let offset = (view["byteOffset"]?.int ?? 0) + (item["byteOffset"]?.int ?? 0)
        return (offset, count, stride, componentType)
    }

    private static func componentCount(_ type: String) -> Int {
        switch type {
        case "VEC2":
            return 2
        case "VEC3":
            return 3
        case "VEC4":
            return 4
        default:
            return 1
        }
    }

    private static func readFloat(_ data: Data, offset: Int) -> Float {
        let bits = readUInt32(data, offset: offset)
        return Float(bitPattern: bits)
    }
}

extension VRMDocumentReader {
    static func readDocument(_ file: GLBFile) -> VRMDocument {
        let vrm0Title = file.json["extensions"]?["VRM"]?["meta"]?["title"]?.string
        let vrm1Name = file.json["extensions"]?["VRMC_vrm"]?["meta"]?["name"]?.string
        let title = (vrm1Name?.isEmpty == false ? vrm1Name : nil) ?? (vrm0Title?.isEmpty == false ? vrm0Title : nil)
        let version = vrm1Name?.isEmpty == false ? "1.0" : (vrm0Title?.isEmpty == false ? "0.x" : nil)
        return VRMDocument(
            glTFVersion: file.version,
            title: title,
            vrmVersion: version,
            generator: file.json["asset"]?["generator"]?.string,
            meshCount: file.json["meshes"]?.arrayCount ?? 0
        )
    }
}
