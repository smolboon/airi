import Foundation

/// BERT WordPiece encoder for the bundled MiniLM vocabulary.
public enum WordPieceTokenizer {
    public static let sequenceLength = 128
    public static let clsID: Int32 = 101
    public static let sepID: Int32 = 102
    public static let padID: Int32 = 0
    public static let unkID: Int32 = 100

    public static func vocabulary(at url: URL) -> [String: Int32] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last?.isEmpty == true {
            lines.removeLast()
        }
        var vocabulary: [String: Int32] = [:]
        vocabulary.reserveCapacity(lines.count)
        for (index, token) in lines.enumerated() {
            vocabulary[token] = Int32(index)
        }
        return vocabulary
    }

    public static func encode(_ text: String, vocabulary: [String: Int32]) -> (ids: [Int32], mask: [Int32]) {
        var ids = [Int32](repeating: padID, count: sequenceLength)
        var mask = [Int32](repeating: 0, count: sequenceLength)
        var pieces: [Int32] = [clsID]
        for word in basicTokens(text) {
            if pieces.count >= sequenceLength - 1 {
                break
            }
            for id in wordPiece(word, vocabulary: vocabulary) {
                if pieces.count >= sequenceLength - 1 {
                    break
                }
                pieces.append(id)
            }
        }
        if pieces.count < sequenceLength {
            pieces.append(sepID)
        }
        let limit = min(pieces.count, sequenceLength)
        for index in 0..<limit {
            ids[index] = pieces[index]
            mask[index] = 1
        }
        return (ids, mask)
    }

    static func basicTokens(_ text: String) -> [String] {
        let folded = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        let lowered = folded.lowercased()
        var words: [String] = []
        for raw in lowered.split(whereSeparator: \.isWhitespace) {
            words.append(contentsOf: splitPunctuation(String(raw)))
        }
        return words.filter { !$0.isEmpty }
    }

    static func splitPunctuation(_ token: String) -> [String] {
        var pieces: [String] = []
        var current = ""
        for character in token {
            if isPunctuation(character) {
                if !current.isEmpty {
                    pieces.append(current)
                    current = ""
                }
                pieces.append(String(character))
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty {
            pieces.append(current)
        }
        return pieces
    }

    static func isPunctuation(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return false
        }
        let value = scalar.value
        if (33...47).contains(value) || (58...64).contains(value) || (91...96).contains(value) || (123...126).contains(value) {
            return true
        }
        return CharacterSet.punctuationCharacters.contains(scalar)
    }

    static func wordPiece(_ word: String, vocabulary: [String: Int32]) -> [Int32] {
        if word.count > 100 {
            return [unkID]
        }
        var output: [Int32] = []
        var start = word.startIndex
        while start < word.endIndex {
            var end = word.endIndex
            var found: Int32?
            while start < end {
                var piece = String(word[start..<end])
                if start != word.startIndex {
                    piece = "##" + piece
                }
                if let id = vocabulary[piece] {
                    found = id
                    break
                }
                end = word.index(before: end)
            }
            guard let found else {
                return [unkID]
            }
            output.append(found)
            start = end
        }
        return output
    }
}
