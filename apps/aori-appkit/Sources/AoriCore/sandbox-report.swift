import Foundation

/// Reads the container id that macOS sets for a sandboxed process.
public enum SandboxReport {
    public static func line(environment: [String: String]) -> String {
        let container = environment["APP_SANDBOX_CONTAINER_ID"] ?? ""
        let trimmed = container.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "aori_sandbox=off"
        }
        return "aori_sandbox=on"
    }
}
