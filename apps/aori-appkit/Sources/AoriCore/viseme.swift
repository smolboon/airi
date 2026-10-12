import Foundation

public enum Viseme: String, Equatable, Sendable {
    case a
    case i
    case u
    case e
    case o
    case pp
    case sil

    /// Raster code. 0 is the A mouth. 5 closes the mouth. 6 is silence.
    public var code: Int32 {
        switch self {
        case .a:
            return 0
        case .i:
            return 1
        case .u:
            return 2
        case .e:
            return 3
        case .o:
            return 4
        case .pp:
            return 5
        case .sil:
            return 6
        }
    }
}

public enum VisemeMap {
    public static func preset(for character: Character) -> Viseme {
        switch String(character).lowercased() {
        case "a":
            return .a
        case "e":
            return .e
        case "i", "y":
            return .i
        case "o":
            return .o
        case "u", "w":
            return .u
        case "m", "b", "p":
            return .pp
        default:
            return .sil
        }
    }
}

public enum VisemeTimeline {
    public static func presets(in phrase: String) -> [Viseme] {
        phrase.map { VisemeMap.preset(for: $0) }
    }

    /// Advances about 12 characters per second of played audio.
    public static func preset(in phrase: String, at seconds: Double) -> Viseme {
        let characters = Array(phrase)
        guard !characters.isEmpty else {
            return .sil
        }
        let index = min(characters.count - 1, max(0, Int(seconds * 12)))
        return VisemeMap.preset(for: characters[index])
    }

    /// Lists each preset change inside one played buffer. A long buffer still covers the vowels.
    public static func presets(in phrase: String, from start: Double, to end: Double) -> [Viseme] {
        let characters = Array(phrase)
        guard !characters.isEmpty else {
            return [.sil]
        }
        let first = min(characters.count - 1, max(0, Int(start * 12)))
        let last = min(characters.count - 1, max(first, Int(end * 12)))
        var result: [Viseme] = []
        for index in first...last {
            let preset = VisemeMap.preset(for: characters[index])
            if result.last != preset {
                result.append(preset)
            }
        }
        return result
    }
}
