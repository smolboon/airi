import CoreGraphics
import Foundation

let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let matches = info.filter { item in
    let owner = item[kCGWindowOwnerName as String] as? String ?? ""
    let title = item[kCGWindowName as String] as? String ?? ""
    return owner == "Aori" || owner == "AoriApp" || title.contains("Aori")
}
if matches.isEmpty {
    fputs("No Aori window. On-screen owners:\n", stderr)
    for item in info {
        let owner = item[kCGWindowOwnerName as String] as? String ?? ""
        let title = item[kCGWindowName as String] as? String ?? ""
        fputs("\(owner) | \(title)\n", stderr)
    }
    exit(1)
}
let role = CommandLine.arguments.dropFirst().first ?? "companion"
guard let chosen = matches.first(where: { item in
    let title = item[kCGWindowName as String] as? String ?? ""
    if role == "main" {
        return title == "Aori"
    }
    return title.contains("Companion")
}) else {
    fputs("No \(role) window.\n", stderr)
    exit(1)
}
let number = chosen[kCGWindowNumber as String] as? Int ?? 0
print(number)
