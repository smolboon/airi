import Foundation

public enum AoriLog {
    public static func frame(milliseconds: Double) -> String {
        String(format: "{\"event\":\"frame\",\"ms\":%.2f}", milliseconds)
    }

    public static func event(_ name: String, fields: [String: String] = [:]) -> String {
        var parts = ["\"event\":\"\(escape(name))\""]
        for key in fields.keys.sorted() {
            parts.append("\"\(escape(key))\":\"\(escape(fields[key] ?? ""))\"")
        }
        return "{\(parts.joined(separator: ","))}"
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
