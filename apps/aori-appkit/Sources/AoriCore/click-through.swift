import Foundation

/// A clear pixel passes the click when click-through is on.
public enum ClickThrough {
    public static func ignores(alpha: UInt8, enabled: Bool) -> Bool {
        enabled && alpha == 0
    }

    /// AppKit view y grows upward. The raster row grows downward.
    public static func rasterY(viewY: Int, height: Int) -> Int {
        height - 1 - viewY
    }

    /// CoreGraphics y grows down from the top of the main display.
    public static func coreGraphicsY(appKitY: Double, screenHeight: Double) -> Double {
        screenHeight - appKitY
    }

    public static func decision(pass: Bool) -> String {
        pass ? "pass" : "keep"
    }
}
