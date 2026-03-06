import ClipperKit
import SwiftUI

@main
struct ClipperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 700)
        }
        .commands {
            ClipperCommands()
        }
        .defaultSize(width: 1200, height: 820)
    }
}
