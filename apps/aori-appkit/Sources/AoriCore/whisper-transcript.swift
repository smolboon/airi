import Foundation

public enum WhisperTranscript {
    /// Reads whisper-cli text. Timestamp lines keep the words after the bracket.
    public static func parse(_ output: String) -> String {
        var parts: [String] = []
        for raw in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || isLog(line) {
                continue
            }
            if let spoken = timestampText(line) {
                if !spoken.isEmpty {
                    parts.append(spoken)
                }
                continue
            }
            parts.append(line)
        }
        return parts.joined(separator: " ")
    }

    private static func isLog(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.hasPrefix("whisper_") || lower.hasPrefix("ggml_") || lower.hasPrefix("main:") {
            return true
        }
        return lower.contains("system_info")
    }

    private static func timestampText(_ line: String) -> String? {
        guard line.contains("-->"), let end = line.firstIndex(of: "]") else {
            return nil
        }
        return String(line[line.index(after: end)...]).trimmingCharacters(in: .whitespaces)
    }
}

public struct OnDeviceRecognizer: Sendable {
    public var binary: String
    public var model: String

    public init(binary: String, model: String) {
        self.binary = binary
        self.model = model
    }

    public static func arguments(model: String, wavPath: String) -> [String] {
        ["-m", model, "-f", wavPath, "-l", "en", "-nt", "-np"]
    }

    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> OnDeviceRecognizer? {
        guard let binary = environment["AORI_WHISPER_BIN"], !binary.isEmpty,
              let model = environment["AORI_WHISPER_MODEL"], !model.isEmpty,
              FileManager.default.isExecutableFile(atPath: binary),
              FileManager.default.fileExists(atPath: model) else {
            return nil
        }
        return OnDeviceRecognizer(binary: binary, model: model)
    }

    public func transcribe(wavPath: String, timeout: TimeInterval = 45) throws -> String {
        let stdoutURL = URL(fileURLWithPath: wavPath + ".whisper-stdout")
        let stderrURL = URL(fileURLWithPath: wavPath + ".whisper-stderr")
        _ = FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        _ = FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = Self.arguments(model: model, wavPath: wavPath)
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let started = Date()
        while process.isRunning {
            if Date().timeIntervalSince(started) > timeout {
                process.terminate()
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        try stdout.close()
        try stderr.close()
        let outText = (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? ""
        let spoken = WhisperTranscript.parse(outText)
        if !spoken.isEmpty {
            return spoken
        }
        let errText = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
        return WhisperTranscript.parse(errText)
    }
}
