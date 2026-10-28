import Foundation

/// Prepares provider text for the transcript and for speech.
public enum SpokenReply {
    public static let sentenceLimit = 3
    public static let characterLimit = 400

    public static func prepare(_ raw: String) -> String {
        var text = stripFences(raw)
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { stripLine(String($0)) }
        text = collapse(lines.joined(separator: " "))
        text = renameBrand(text)
        text = limitSentences(text, limit: sentenceLimit)
        text = limitCharacters(text, limit: characterLimit)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripFences(_ raw: String) -> String {
        var text = raw
        while let open = text.range(of: "```") {
            let after = text[open.upperBound...]
            if let close = after.range(of: "```") {
                text.removeSubrange(open.lowerBound..<close.upperBound)
            } else {
                text.removeSubrange(open.lowerBound..<text.endIndex)
            }
        }
        return text
    }

    private static func stripLine(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        while text.hasPrefix("#") {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespaces)
        }
        if text.hasPrefix("- ") || text.hasPrefix("* ") || text.hasPrefix("+ ") {
            text.removeFirst(2)
        }
        text = labelsOnly(text)
        text.removeAll { character in
            character == "*" || character == "_" || character == "`"
        }
        return text
    }

    private static func labelsOnly(_ line: String) -> String {
        var result = ""
        var index = line.startIndex
        while index < line.endIndex {
            if line[index] == "[",
               let endLabel = line[line.index(after: index)...].firstIndex(of: "]"),
               line.index(after: endLabel) < line.endIndex,
               line[line.index(after: endLabel)] == "(" ,
               let endURL = line[line.index(after: endLabel)...].firstIndex(of: ")") {
                let labelStart = line.index(after: index)
                result.append(contentsOf: line[labelStart..<endLabel])
                index = line.index(after: endURL)
                continue
            }
            result.append(line[index])
            index = line.index(after: index)
        }
        return result
    }

    private static func collapse(_ text: String) -> String {
        let parts = text.split { $0.isWhitespace }
        return parts.joined(separator: " ")
    }

    private static func renameBrand(_ text: String) -> String {
        var result = ""
        var word = ""
        func flush() {
            if word.lowercased() == "airi" {
                result.append("Aori")
            } else {
                result.append(word)
            }
            word = ""
        }
        for character in text {
            if character.isLetter {
                word.append(character)
            } else {
                flush()
                result.append(character)
            }
        }
        flush()
        return result
    }

    private static func limitSentences(_ text: String, limit: Int) -> String {
        guard limit > 0 else {
            return ""
        }
        var count = 0
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            if character == "." || character == "!" || character == "?" {
                let previous = index > text.startIndex ? text[text.index(before: index)] : " "
                let following = next < text.endIndex ? text[next] : " "
                let decimal = previous.isNumber && following.isNumber
                if !decimal {
                    count += 1
                    if count >= limit {
                        return String(text[..<next])
                    }
                }
            }
            index = next
        }
        return text
    }

    private static func limitCharacters(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }
        let end = text.index(text.startIndex, offsetBy: limit)
        let prefix = String(text[..<end])
        if let space = prefix.lastIndex(of: " "), space > prefix.startIndex {
            return String(prefix[..<space])
        }
        return prefix
    }
}
