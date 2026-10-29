import Foundation

/// One local chat command. It does not open a host and it does not start speech.
public enum LocalTool {
    public static let command = "tool greeting"

    public static func reply(to text: String) -> String? {
        guard text == command else {
            return nil
        }
        return PluginHost.greetingText
    }
}
