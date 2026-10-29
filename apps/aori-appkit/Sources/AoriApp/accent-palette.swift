import AppKit
import AoriCore

enum AccentPalette {
    static var fill: NSColor {
        NSColor(
            srgbRed: CGFloat(AccentColor.red) / 255,
            green: CGFloat(AccentColor.green) / 255,
            blue: CGFloat(AccentColor.blue) / 255,
            alpha: 1
        )
    }

    static var ink: NSColor {
        NSColor(
            srgbRed: CGFloat(AccentColor.foregroundRed) / 255,
            green: CGFloat(AccentColor.foregroundGreen) / 255,
            blue: CGFloat(AccentColor.foregroundBlue) / 255,
            alpha: 1
        )
    }

    static var textScrim: NSColor {
        NSColor.black.withAlphaComponent(CGFloat(MetaBalls.textScrimAlpha))
    }

    static func apply(to button: NSButton) {
        button.bezelColor = fill
        button.contentTintColor = ink
        let font = button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: ink,
                .font: font,
            ]
        )
    }
}
