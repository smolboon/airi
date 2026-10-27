import Foundation

public enum ScreenCapturePermission: String, Equatable, Sendable {
    case granted
    case denied
    case unavailable
}

public enum VisionSource: String, Equatable, Sendable {
    case screen
    case fixture
    case none
}

public protocol VisionCompletionClient: Sendable {
    func streamVision(
        png: Data,
        configuration: ProviderConfiguration
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error>
}

public enum VisionImage {
    public static let maxBytes = 1_500_000

    public static func isPNG(_ data: Data) -> Bool {
        guard data.count >= 8, data.count <= maxBytes else {
            return false
        }
        let magic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        return data.prefix(8).elementsEqual(magic)
    }

    public static func dataURL(png: Data) -> String? {
        guard isPNG(png) else {
            return nil
        }
        return "data:image/png;base64,\(png.base64EncodedString())"
    }
}

/// Picks the frame that the provider receives.
/// A denied capture never becomes a screen frame.
public enum VisionCapturePlan {
    public static func select(
        permission: ScreenCapturePermission,
        screenPNG: Data?,
        fixturePNG: Data?
    ) -> (source: VisionSource, png: Data?) {
        if permission == .granted, let screenPNG, VisionImage.isPNG(screenPNG) {
            return (.screen, screenPNG)
        }
        if let fixturePNG, VisionImage.isPNG(fixturePNG) {
            return (.fixture, fixturePNG)
        }
        return (.none, nil)
    }
}

public enum VisionRequest {
    public static let workload = "screen:interpret"
    public static let prompt = [
        "You are an on-device vision assistant.",
        "Interpret the current screen in a concise, structured summary:",
        "- identify the active app or page",
        "- list key UI elements and their states",
        "- call out user intent or next likely action",
        "Keep it factual and short, avoid speculation.",
    ].joined(separator: "\n")

    public static func encode(model: String, png: Data) throws -> Data {
        guard let url = VisionImage.dataURL(png: png) else {
            throw ChatProviderError.invalidVisionFrame
        }
        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": url]],
                    ],
                ],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }
}

public struct LocalVisionClient: VisionCompletionClient {
    public init() {}

    public func streamVision(
        png: Data,
        configuration _: ProviderConfiguration
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        guard VisionImage.isPNG(png) else {
            throw ChatProviderError.invalidVisionFrame
        }
        let reply = "I can see a frame. This reply is a template."
        return AsyncThrowingStream { continuation in
            continuation.yield(.delta(reply))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}
