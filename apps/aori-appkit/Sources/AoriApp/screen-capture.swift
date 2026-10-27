import AoriCore
import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

enum ScreenCaptureResult: Sendable {
    case png(Data)
    case empty
    case error
    case timeout
}

enum ScreenCaptureSession {
    static func preflight() -> ScreenCapturePermission {
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }
        return .denied
    }

    /// Asks macOS for screen recording access. A dialog can appear.
    static func requestAccess() -> ScreenCapturePermission {
        if CGRequestScreenCaptureAccess() {
            return .granted
        }
        return .denied
    }

    static func capturePNG() async -> ScreenCaptureResult {
        await withTaskGroup(of: ScreenCaptureResult.self) { group in
            group.addTask {
                await takePNG()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(4))
                return .timeout
            }
            let first = await group.next() ?? .timeout
            group.cancelAll()
            return first
        }
    }

    private static func takePNG() async -> ScreenCaptureResult {
        if Task.isCancelled {
            return .empty
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                return .empty
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = 320
            configuration.height = 180
            configuration.scalesToFit = true
            configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            guard let png = pngData(from: image), VisionImage.isPNG(png) else {
                return .empty
            }
            return .png(png)
        } catch {
            return .error
        }
    }

    private static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }
}
