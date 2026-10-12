import Foundation

public struct VRMHumanBone: Equatable, Sendable {
    public var name: String
    public var node: Int

    public init(name: String, node: Int) {
        self.name = name
        self.node = node
    }
}

public enum VRMHumanoidReader {
    /// Reads VRM 0 `extensions.VRM.humanoid.humanBones`.
    public static func bones(in data: Data) throws -> [VRMHumanBone] {
        let file = try GLBFileReader.read(data)
        let bones = file.json["extensions"]?["VRM"]?["humanoid"]?["humanBones"]?.array ?? []
        return bones.compactMap { bone in
            guard let name = bone["bone"]?.string, let node = bone["node"]?.int else {
                return nil
            }
            return VRMHumanBone(name: name, node: node)
        }
    }
}
