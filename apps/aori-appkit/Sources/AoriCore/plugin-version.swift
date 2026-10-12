import Foundation

struct PluginVersion: Equatable {
    var major: Int
    var minor: Int
    var patch: Int

    static func parseExact(_ text: String) -> PluginVersion? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let major = exactNumber(parts[0]),
              let minor = exactNumber(parts[1]),
              let patch = exactNumber(parts[2])
        else {
            return nil
        }
        return PluginVersion(major: major, minor: minor, patch: patch)
    }
}

enum PluginVersionRange: Equatable {
    case any
    case exact(PluginVersion)
    case caret(PluginVersion)
    case tilde(PluginVersion)
    case atLeast(PluginVersion)
    case above(PluginVersion)
    case atMost(PluginVersion)
    case below(PluginVersion)
    indirect case both(PluginVersionRange, PluginVersionRange)

    static func parse(_ text: String) -> PluginVersionRange? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "*" {
            return .any
        }
        let pieces = trimmed.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if pieces.count == 2 {
            guard let left = parseOne(pieces[0]), let right = parseOne(pieces[1]) else {
                return nil
            }
            return .both(left, right)
        }
        guard pieces.count == 1 else {
            return nil
        }
        return parseOne(pieces[0])
    }

    func matches(_ version: PluginVersion) -> Bool {
        switch self {
        case .any:
            return true
        case .exact(let required):
            return version == required
        case .caret(let required):
            guard version >= required else {
                return false
            }
            if required.major > 0 {
                return version.major == required.major
            }
            if required.minor > 0 {
                return version.major == 0 && version.minor == required.minor
            }
            return version == required
        case .tilde(let required):
            return version >= required && version.major == required.major && version.minor == required.minor
        case .atLeast(let required):
            return version >= required
        case .above(let required):
            return version > required
        case .atMost(let required):
            return version <= required
        case .below(let required):
            return version < required
        case .both(let left, let right):
            return left.matches(version) && right.matches(version)
        }
    }

    private static func parseOne(_ text: String) -> PluginVersionRange? {
        let prefixes: [(String, (PluginVersion) -> PluginVersionRange)] = [
            ("^", { .caret($0) }),
            ("~", { .tilde($0) }),
            (">=", { .atLeast($0) }),
            ("<=", { .atMost($0) }),
            (">", { .above($0) }),
            ("<", { .below($0) }),
            ("=", { .exact($0) }),
        ]
        for prefix in prefixes where text.hasPrefix(prefix.0) {
            let rest = String(text.dropFirst(prefix.0.count))
            guard let version = PluginVersion.parseExact(rest) else {
                return nil
            }
            return prefix.1(version)
        }
        guard let version = PluginVersion.parseExact(text) else {
            return nil
        }
        return .exact(version)
    }
}

extension PluginVersion: Comparable {
    static func < (lhs: PluginVersion, rhs: PluginVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}

private func exactNumber(_ text: Substring) -> Int? {
    guard !text.isEmpty, text.allSatisfy(\.isNumber) else {
        return nil
    }
    if text.count > 1, text.hasPrefix("0") {
        return nil
    }
    return Int(text)
}
