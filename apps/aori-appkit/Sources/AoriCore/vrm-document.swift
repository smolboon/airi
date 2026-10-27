import Foundation

public struct VRMDocument: Equatable, Sendable {
    public var glTFVersion: UInt32
    public var title: String?
    public var vrmVersion: String?
    public var generator: String?
    public var meshCount: Int

    public init(glTFVersion: UInt32, title: String?, vrmVersion: String?, generator: String?, meshCount: Int) {
        self.glTFVersion = glTFVersion
        self.title = title
        self.vrmVersion = vrmVersion
        self.generator = generator
        self.meshCount = meshCount
    }
}

public enum VRMDocumentError: Error, Equatable, Sendable, CustomStringConvertible {
    case tooSmall
    case badMagic
    case truncated
    case missingJSONChunk
    case invalidJSON

    public var description: String {
        switch self {
        case .tooSmall:
            return "The file is too small to be a VRM model."
        case .badMagic:
            return "The file is not a binary glTF VRM model."
        case .truncated:
            return "The VRM file is truncated."
        case .missingJSONChunk:
            return "The VRM file has no JSON chunk."
        case .invalidJSON:
            return "The VRM JSON chunk is not valid."
        }
    }
}

struct GLBFile {
    var version: UInt32
    var json: JSONValue
    var bin: Data
}

enum GLBFileReader {
    static func read(_ data: Data) throws -> GLBFile {
        guard data.count >= 20 else {
            throw VRMDocumentError.tooSmall
        }
        let magic = readUInt32(data, offset: 0)
        guard magic == 0x4654_6C67 else {
            throw VRMDocumentError.badMagic
        }
        let version = readUInt32(data, offset: 4)
        let length = Int(readUInt32(data, offset: 8))
        guard length <= data.count else {
            throw VRMDocumentError.truncated
        }

        var offset = 12
        var json: JSONValue?
        var bin = Data()
        while offset + 8 <= length {
            let chunkLength = Int(readUInt32(data, offset: offset))
            let chunkType = readUInt32(data, offset: offset + 4)
            let start = offset + 8
            let end = start + chunkLength
            guard end <= length else {
                throw VRMDocumentError.truncated
            }
            let chunk = data.subdata(in: start..<end)
            if chunkType == 0x4E4F_534A {
                do {
                    json = try JSONDecoder().decode(JSONValue.self, from: trimJSONPadding(chunk))
                } catch {
                    throw VRMDocumentError.invalidJSON
                }
            } else if chunkType == 0x004E_4942 {
                bin = chunk
            }
            offset = end
        }
        guard let json else {
            throw VRMDocumentError.missingJSONChunk
        }
        return GLBFile(version: version, json: json, bin: bin)
    }
}

public enum VRMDocumentReader {
    public static func read(_ data: Data) throws -> VRMDocument {
        let file = try GLBFileReader.read(data)
        return map(file.json, version: file.version)
    }

    private static func map(_ json: JSONValue, version: UInt32) -> VRMDocument {
        let vrm0Title = json["extensions"]?["VRM"]?["meta"]?["title"]?.string
        let vrm1Name = json["extensions"]?["VRMC_vrm"]?["meta"]?["name"]?.string
        let vrmVersion: String?
        let title: String?
        if let vrm1Name, !vrm1Name.isEmpty {
            title = vrm1Name
            vrmVersion = "1.0"
        } else if let vrm0Title, !vrm0Title.isEmpty {
            title = vrm0Title
            vrmVersion = "0.x"
        } else {
            title = nil
            vrmVersion = nil
        }
        return VRMDocument(
            glTFVersion: version,
            title: title,
            vrmVersion: vrmVersion,
            generator: json["asset"]?["generator"]?.string,
            meshCount: json["meshes"]?.arrayCount ?? 0
        )
    }
}

func readUInt32(_ data: Data, offset: Int) -> UInt32 {
    let start = data.startIndex + offset
    let b0 = UInt32(data[start])
    let b1 = UInt32(data[start + 1])
    let b2 = UInt32(data[start + 2])
    let b3 = UInt32(data[start + 3])
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

func trimJSONPadding(_ data: Data) -> Data {
    var end = data.count
    while end > 0 {
        let byte = data[data.index(data.startIndex, offsetBy: end - 1)]
        if byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 || byte == 0x00 {
            end -= 1
        } else {
            break
        }
    }
    return data.prefix(end)
}
