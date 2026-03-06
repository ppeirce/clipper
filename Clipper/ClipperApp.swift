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
    static func apply() {
        guard let mainMenu = NSApp.mainMenu else {
            return
        }

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

        let replacementMenu = NSMenu(title: existingMenu.title)
        let retainedItems = existingMenu.items.filter { item in
            guard !item.isSeparatorItem else {
                return false
            }
            return item.keyEquivalentModifierMask.contains(.command) &&
                ["z", "Z"].contains(item.keyEquivalent)
        }

        guard !retainedItems.isEmpty else {
            return
        }

        for item in retainedItems {
            existingMenu.removeItem(item)
            replacementMenu.addItem(item)
        }

        editMenuItem.submenu = replacementMenu
    }

    private static func removeTopLevelMenu(titled title: String, from mainMenu: NSMenu) {
        guard let index = mainMenu.items.firstIndex(where: { $0.title == title }) else {
            return
        }
        mainMenu.removeItem(at: index)
    }
}
