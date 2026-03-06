import AppKit
import Foundation

@MainActor
protocol RecentDocumentManaging: AnyObject {
    var recentDocumentURLs: [URL] { get }

    func noteRecentDocument(_ url: URL)
    func clearRecentDocuments()
}

@MainActor
final class AppRecentDocumentManager: RecentDocumentManaging {
    private let documentController: NSDocumentController

    init(documentController: NSDocumentController = .shared) {
        self.documentController = documentController
    }

    var recentDocumentURLs: [URL] {
        documentController.recentDocumentURLs
    }

    func noteRecentDocument(_ url: URL) {
        documentController.noteNewRecentDocumentURL(url)
    }

    func clearRecentDocuments() {
        documentController.clearRecentDocuments(nil)
    }
}

enum SupportedVideoSource {
    static let supportedExtensions: Set<String> = [
        "mp4",
        "mov",
        "m4v",
        "h264",
        "h265",
        "hevc"
    ]

    static let unsupportedMessage = "Unsupported video format. Open MP4, MOV, M4V, H.264, or H.265 files."

    static func supports(_ url: URL) -> Bool {
        guard url.isFileURL else {
            return false
        }

        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func filterRecentDocumentURLs(_ urls: [URL]) -> [URL] {
        var seenPaths = Set<String>()

        return urls.filter { url in
            guard supports(url) else {
                return false
            }

            return seenPaths.insert(url.standardizedFileURL.path).inserted
        }
    }
}
