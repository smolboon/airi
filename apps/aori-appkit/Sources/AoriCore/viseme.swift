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

public enum PhonemeMap {
    /// Maps an ARPAbet symbol to a mouth preset. This is a table, not a recognizer.
    public static func viseme(for symbol: String) -> Viseme {
        switch symbol.uppercased() {
        case "AA", "AH", "AE":
            return .a
        case "IH", "IY":
            return .i
        case "UW", "UH":
            return .u
        case "EH", "EY":
            return .e
        case "OW", "AO", "OY":
            return .o
        case "M", "B", "P":
            return .pp
        default:
            return .sil
        }
    }
}

public enum PhonemeLexicon {
    /// Known words become ARPAbet symbols. Other words stay on the letter map.
    public static let words: [String: [String]] = [
        "hello": ["HH", "EH", "L", "OW"],
        "papa": ["P", "AA", "P", "AH"],
        "here": ["HH", "IH", "R"],
    ]
}

public enum SpeechUnit: Equatable, Sendable {
    case phoneme(String)
    case letter(Character)
}

public enum PhonemeTimeline {
    public static func units(in phrase: String) -> [SpeechUnit] {
        var result: [SpeechUnit] = []
        for word in words(in: phrase) {
            if let phonemes = PhonemeLexicon.words[word] {
                result.append(contentsOf: phonemes.map { .phoneme($0) })
            } else {
                result.append(contentsOf: word.map { .letter($0) })
            }
        }
        return result
    }

    public static func symbols(in phrase: String) -> [String] {
        units(in: phrase).map { unit in
            switch unit {
            case .phoneme(let symbol):
                return symbol
            case .letter(let character):
                return String(character)
            }
        }
    }

    public static func visemes(in phrase: String) -> [Viseme] {
        units(in: phrase).map { unit in
            switch unit {
            case .phoneme(let symbol):
                return PhonemeMap.viseme(for: symbol)
            case .letter(let character):
                return VisemeMap.preset(for: character)
            }
        }
    }

    private static func words(in phrase: String) -> [String] {
        phrase.lowercased().split { !$0.isLetter }.map(String.init)
    }
}

public enum VisemeTimeline {
    public static func presets(in phrase: String) -> [Viseme] {
        let units = PhonemeTimeline.visemes(in: phrase)
        return units.isEmpty ? [.sil] : units
    }

    /// Advances about 12 units per second of played audio.
    public static func preset(in phrase: String, at seconds: Double) -> Viseme {
        let units = presets(in: phrase)
        guard !units.isEmpty else {
            return .sil
        }
        let index = min(units.count - 1, max(0, Int(seconds * 12)))
        return units[index]
    }

    /// Lists each preset change inside one played buffer. A long buffer still covers the vowels.
    public static func presets(in phrase: String, from start: Double, to end: Double) -> [Viseme] {
        let units = presets(in: phrase)
        guard !units.isEmpty else {
            return [.sil]
        }
        let first = min(units.count - 1, max(0, Int(start * 12)))
        let last = min(units.count - 1, max(first, Int(end * 12)))
        var result: [Viseme] = []
        for index in first...last {
            let preset = units[index]
            if result.last != preset {
                result.append(preset)
            }
        }
        return result
    }
}
