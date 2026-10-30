import Foundation

public struct CompanionWindowPolicy: Equatable, Sendable {
    public var transparent: Bool
    public var alwaysOnTop: Bool
    public var visibleOnAllSpaces: Bool
    public var movableByBackground: Bool
    public var hidesTitlebar: Bool
    public var clickThrough: Bool

    public init(
        transparent: Bool,
        alwaysOnTop: Bool,
        visibleOnAllSpaces: Bool,
        movableByBackground: Bool,
        hidesTitlebar: Bool,
        clickThrough: Bool
    ) {
        self.transparent = transparent
        self.alwaysOnTop = alwaysOnTop
        self.visibleOnAllSpaces = visibleOnAllSpaces
        self.movableByBackground = movableByBackground
        self.hidesTitlebar = hidesTitlebar
        self.clickThrough = clickThrough
    }

    public static let standard = CompanionWindowPolicy(
        transparent: true,
        alwaysOnTop: true,
        visibleOnAllSpaces: true,
        movableByBackground: true,
        hidesTitlebar: true,
        clickThrough: false
    )
}

public struct CompanionWindowStyle: Equatable, Sendable {
    public var floating: Bool
    public var transparent: Bool
    public var borderless: Bool
    public var joinsAllSpaces: Bool
    public var movableByBackground: Bool

    public init(
        floating: Bool,
        transparent: Bool,
        borderless: Bool,
        joinsAllSpaces: Bool,
        movableByBackground: Bool
    ) {
        self.floating = floating
        self.transparent = transparent
        self.borderless = borderless
        self.joinsAllSpaces = joinsAllSpaces
        self.movableByBackground = movableByBackground
    }
}

extension CompanionWindowPolicy {
    public func style() -> CompanionWindowStyle {
        CompanionWindowStyle(
            floating: alwaysOnTop,
            transparent: transparent,
            borderless: hidesTitlebar,
            joinsAllSpaces: visibleOnAllSpaces,
            movableByBackground: movableByBackground
        )
    }
}
