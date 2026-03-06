import ClipperKit
import SwiftUI

@main
struct ClipperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    minWidth: ContentView.minimumWindowWidth,
                    minHeight: ContentView.minimumWindowHeight
                )
        }
        .commands {
            ClipperCommands()
        }
        .defaultSize(
            width: ContentView.minimumWindowWidth,
            height: ContentView.minimumWindowHeight
        )
    }
}
