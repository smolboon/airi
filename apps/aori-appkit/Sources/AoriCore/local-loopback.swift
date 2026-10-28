import Foundation

/// Hosts that stay on this machine. The check reads the URL host. It does not use DNS.
public enum LocalLoopback {
    public static func allows(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        guard let host = url.host?.lowercased() else {
            return false
        }
        return host == "localhost" || host == "127.0.0.1"
    }
}

public enum ChatRoute {
    /// A remote URL with an empty key stays on the device template. A loopback URL calls the chat server.
    public static func usesDeviceTemplate(_ configuration: ProviderConfiguration) -> Bool {
        if configuration.model == "local" {
            return true
        }
        if configuration.apiKey.isEmpty {
            return !LocalLoopback.allows(configuration.baseURL)
        }
        return false
    }

    public static func missingKeyStatus(baseURL: URL) -> String {
        if LocalLoopback.allows(baseURL) {
            return "No API key is set. A local server on this machine does not need one."
        }
        return "No API key is set. Open Settings, or set AORI_OPENAI_API_KEY."
    }

    public static func keyPlaceholder(baseURL: URL, keyIsEmpty: Bool) -> String {
        if !keyIsEmpty {
            return "Saved. Type a new key to replace it."
        }
        if LocalLoopback.allows(baseURL) {
            return "API key. Optional on this machine."
        }
        return "API key"
    }
}
