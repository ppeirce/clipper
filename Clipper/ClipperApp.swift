import AppKit
import ClipperKit
import SwiftUI

@main
struct ClipperApp: App {
    @NSApplicationDelegateAdaptor(ClipperAppDelegate.self) private var appDelegate

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup(id: ClipperWindowIdentifiers.mainWindow) {
            mainWindowContent
        }
        .commands {
            ClipperCommands()
        }
        .defaultSize(
            width: ContentView.minimumWindowWidth,
            height: ContentView.minimumWindowHeight
        )
    }

    @ViewBuilder
    private var mainWindowContent: some View {
        ContentView()
            .frame(
                minWidth: ContentView.minimumWindowWidth,
                minHeight: ContentView.minimumWindowHeight
            )
    }
}

@MainActor
final class ClipperAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarCleanup.install()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        DispatchQueue.main.async {
            ClipperWindowCoordinator.shared.openInitialWindowIfNeeded()
            MenuBarCleanup.apply()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        MenuBarCleanup.apply()
    }

    @IBAction func newWindowForTab(_ sender: Any?) {
        ClipperWindowCoordinator.shared.handleNewTabRequest()
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        MenuBarCleanup.apply()
    }
}

@MainActor
private enum MenuBarCleanup {
    private static let editMenuTitlesToKeep: Set<String> = ["Undo", "Redo"]
    private static let sharedDelegate = MenuDelegate()
    private static var didInstall = false
    private static var addObserver: NSObjectProtocol?

    static func install() {
        guard !didInstall else {
            return
        }

        didInstall = true
        addObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didAddItemNotification,
            object: nil,
            queue: nil
        ) { _ in
            DispatchQueue.main.async {
                apply()
            }
        }
    }

    static func apply() {
        guard let mainMenu = NSApp.mainMenu else {
            return
        }

        mainMenu.delegate = sharedDelegate
        pruneEditMenu(in: mainMenu)
        removeTopLevelMenu(titled: "Format", from: mainMenu)
    }

    private static func pruneEditMenu(in mainMenu: NSMenu) {
        guard
            let editMenuItem = mainMenu.items.first(where: { $0.title == "Edit" }),
            let existingMenu = editMenuItem.submenu
        else {
            return
        }

        existingMenu.delegate = sharedDelegate

        for index in existingMenu.items.indices.reversed() {
            let item = existingMenu.items[index]
            guard !shouldKeepEditMenuItem(item) else {
                continue
            }
            existingMenu.removeItem(at: index)
        }

        trimSeparators(in: existingMenu)
    }

    private static func shouldKeepEditMenuItem(_ item: NSMenuItem) -> Bool {
        guard !item.isSeparatorItem else {
            return false
        }

        guard editMenuTitlesToKeep.contains(item.title) else {
            return false
        }

        return item.keyEquivalentModifierMask.contains(.command) &&
            ["z", "Z"].contains(item.keyEquivalent)
    }

    private static func trimSeparators(in menu: NSMenu) {
        for index in menu.items.indices.reversed() where menu.items[index].isSeparatorItem {
            let isLeading = index == 0
            let isTrailing = index == menu.items.count - 1
            let isDuplicate = !isTrailing && menu.items[index + 1].isSeparatorItem

            if isLeading || isTrailing || isDuplicate {
                menu.removeItem(at: index)
            }
        }
    }

    private static func removeTopLevelMenu(titled title: String, from mainMenu: NSMenu) {
        guard let index = mainMenu.items.firstIndex(where: { $0.title == title }) else {
            return
        }
        mainMenu.removeItem(at: index)
    }

    private final class MenuDelegate: NSObject, NSMenuDelegate {
        func menuWillOpen(_ menu: NSMenu) {
            apply()
        }
    }
}
