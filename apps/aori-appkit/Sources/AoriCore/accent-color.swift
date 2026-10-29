import Foundation

/// The one accent for Aori. Fills use `hex`. Text on a fill uses `foregroundHex`.
public enum AccentColor {
    public static let hex = "FFEA00"
    public static let css = "#FFEA00"
    public static let red = 255
    public static let green = 234
    public static let blue = 0

    /// Near-black ink. Yellow text on a light surface fails WCAG AA.
    public static let foregroundHex = "141414"
    public static let foregroundCSS = "#141414"
    public static let foregroundRed = 20
    public static let foregroundGreen = 20
    public static let foregroundBlue = 20

    public static let minimumContrast = 4.5

    public static func relativeLuminance(red: Int, green: Int, blue: Int) -> Double {
        func channel(_ value: Int) -> Double {
            let scaled = Double(value) / 255
            if scaled <= 0.04045 {
                return scaled / 12.92
            }
            return pow((scaled + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    public static func contrastRatio(
        foregroundRed: Int,
        foregroundGreen: Int,
        foregroundBlue: Int,
        backgroundRed: Int,
        backgroundGreen: Int,
        backgroundBlue: Int
    ) -> Double {
        let foreground = relativeLuminance(red: foregroundRed, green: foregroundGreen, blue: foregroundBlue)
        let background = relativeLuminance(red: backgroundRed, green: backgroundGreen, blue: backgroundBlue)
        let lighter = max(foreground, background)
        let darker = min(foreground, background)
        return (lighter + 0.05) / (darker + 0.05)
    }

    public static func inkOnFillPassesAA() -> Bool {
        contrastRatio(
            foregroundRed: foregroundRed,
            foregroundGreen: foregroundGreen,
            foregroundBlue: foregroundBlue,
            backgroundRed: red,
            backgroundGreen: green,
            backgroundBlue: blue
        ) >= minimumContrast
    }

    /// White on the yellow fill is below WCAG AA for normal text.
    public static func whiteOnFillPassesAA() -> Bool {
        contrastRatio(
            foregroundRed: 255,
            foregroundGreen: 255,
            foregroundBlue: 255,
            backgroundRed: red,
            backgroundGreen: green,
            backgroundBlue: blue
        ) >= minimumContrast
    }
}
