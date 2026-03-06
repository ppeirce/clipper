import OSLog

enum AppLogger {
    static let app = Logger(subsystem: "com.peter.clipper", category: "app")
    static let playback = Logger(subsystem: "com.peter.clipper", category: "playback")
    static let export = Logger(subsystem: "com.peter.clipper", category: "export")
}
