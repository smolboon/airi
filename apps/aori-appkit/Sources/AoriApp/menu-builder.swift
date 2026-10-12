import AppKit
import AoriCore

struct InstalledMenu {
    var alwaysOnTopItem: NSMenuItem
}

@MainActor
enum MenuBuilder {
    static func install(target: AnyObject) -> InstalledMenu {
        let main = NSMenu()

        let appMenu = NSMenu(title: AoriCopy.appName)
        bind(appMenu.addItem(withTitle: AoriCopy.about, action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: ""), target: target)
        appMenu.addItem(.separator())
        bind(appMenu.addItem(withTitle: AoriCopy.settings, action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ","), target: target)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: AoriCopy.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.title = AoriCopy.appName
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileMenu = NSMenu(title: "File")
        bind(fileMenu.addItem(withTitle: AoriCopy.newChat, action: #selector(AppDelegate.newChat(_:)), keyEquivalent: "n"), target: target)
        bind(fileMenu.addItem(withTitle: AoriCopy.openVRM, action: #selector(AppDelegate.openVRM(_:)), keyEquivalent: "o"), target: target)
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let fileItem = NSMenuItem()
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        main.addItem(editItem)

        let viewMenu = NSMenu(title: "View")
        bind(viewMenu.addItem(withTitle: AoriCopy.showMainWindow, action: #selector(AppDelegate.showMainWindow(_:)), keyEquivalent: "1"), target: target)
        bind(viewMenu.addItem(withTitle: AoriCopy.showCompanion, action: #selector(AppDelegate.showCompanion(_:)), keyEquivalent: "2"), target: target)
        bind(viewMenu.addItem(withTitle: AoriCopy.hideCompanion, action: #selector(AppDelegate.hideCompanion(_:)), keyEquivalent: "3"), target: target)
        let alwaysOnTop = viewMenu.addItem(
            withTitle: AoriCopy.alwaysOnTop,
            action: #selector(AppDelegate.toggleAlwaysOnTop(_:)),
            keyEquivalent: "t"
        )
        bind(alwaysOnTop, target: target)
        let viewItem = NSMenuItem()
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
        return InstalledMenu(alwaysOnTopItem: alwaysOnTop)
    }

    private static func bind(_ item: NSMenuItem, target: AnyObject) {
        item.target = target
    }
}
