import AppKit
import AoriCore

@MainActor
final class StatusItemController {
    private let item: NSStatusItem

    init(target: AnyObject) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: AoriCopy.statusItem)
        image?.isTemplate = true
        item.button?.image = image
        let menu = NSMenu()
        add(AoriCopy.showCompanion, action: #selector(AppDelegate.showCompanion(_:)), target: target, menu: menu)
        add(AoriCopy.showMainWindow, action: #selector(AppDelegate.showMainWindow(_:)), target: target, menu: menu)
        add(AoriCopy.settings, action: #selector(AppDelegate.showSettings(_:)), target: target, menu: menu)
        menu.addItem(.separator())
        menu.addItem(withTitle: AoriCopy.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        item.menu = menu
    }

    private func add(_ title: String, action: Selector, target: AnyObject, menu: NSMenu) {
        let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        entry.target = target
    }
}
