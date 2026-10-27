import Foundation

enum JSONValue: Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    subscript(key: String) -> JSONValue? {
        guard case .object(let object) = self else {
            return nil
        }
        return object[key]
    }

    var string: String? {
        guard case .string(let value) = self else {
            return nil
        }
        return value
    }

    var arrayCount: Int {
        guard case .array(let values) = self else {
            return 0
        }
        return values.count
    }

    var array: [JSONValue] {
        guard case .array(let values) = self else {
            return []
        }
        return values
    }

    var double: Double? {
        guard case .number(let value) = self else {
            return nil
        }
        return value
    }

    var int: Int? {
        guard let double else {
            return nil
        }
        return Int(double)
    }

    subscript(index: Int) -> JSONValue? {
        guard case .array(let values) = self, values.indices.contains(index) else {
            return nil
        }
        return values[index]
    }
}

extension JSONValue: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown JSON value")
    }
}
