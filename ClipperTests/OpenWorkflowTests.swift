import AVFoundation
import XCTest
@testable import ClipperKit

@MainActor
final class OpenWorkflowTests: XCTestCase {
    func testSupportedVideoSourceAcceptsKnownVideoExtensions() {
        XCTAssertTrue(SupportedVideoSource.supports(URL(fileURLWithPath: "/tmp/source.mp4")))
        XCTAssertTrue(SupportedVideoSource.supports(URL(fileURLWithPath: "/tmp/source.MOV")))
        XCTAssertTrue(SupportedVideoSource.supports(URL(fileURLWithPath: "/tmp/source.m4v")))
        XCTAssertTrue(SupportedVideoSource.supports(URL(fileURLWithPath: "/tmp/source.h264")))
        XCTAssertTrue(SupportedVideoSource.supports(URL(fileURLWithPath: "/tmp/source.h265")))
        XCTAssertTrue(SupportedVideoSource.supports(URL(fileURLWithPath: "/tmp/source.hevc")))
    }

    func testSupportedVideoSourceRejectsUnsupportedExtensions() {
        XCTAssertFalse(SupportedVideoSource.supports(URL(fileURLWithPath: "/tmp/source.txt")))
        XCTAssertFalse(SupportedVideoSource.supports(URL(fileURLWithPath: "/tmp/source")))
        XCTAssertFalse(SupportedVideoSource.supports(URL(string: "https://example.com/source.mp4")!))
    }

    func testRecentVideoFilteringKeepsSupportedUniqueEntries() {
        let mov = URL(fileURLWithPath: "/tmp/source.mov")
        let duplicateMov = URL(fileURLWithPath: "/tmp/../tmp/source.mov")
        let mp4 = URL(fileURLWithPath: "/tmp/other.mp4")
        let text = URL(fileURLWithPath: "/tmp/readme.txt")

        let recentURLs = SupportedVideoSource.filterRecentDocumentURLs([mov, duplicateMov, text, mp4])

        XCTAssertEqual(recentURLs, [mov, mp4])
    }

    func testLoadVideoRecordsRecentDocumentOnSuccess() async {
        let sourceURL = URL(fileURLWithPath: "/tmp/source.mov")
        let playbackController = PlaybackControllerSpy()
        let recentDocuments = RecentDocumentManagerSpy()
        let viewModel = makeViewModel(
            playbackController: playbackController,
            recentDocuments: recentDocuments
        )

        await viewModel.loadVideo(url: sourceURL)

        XCTAssertEqual(playbackController.loadedURLs, [sourceURL])
        XCTAssertEqual(viewModel.state.asset?.url, sourceURL)
        XCTAssertEqual(recentDocuments.notedURLs, [sourceURL])
        XCTAssertEqual(viewModel.recentVideoURLs, [sourceURL])
    }

    func testLoadUnsupportedVideoDoesNotHitPlaybackOrRecents() async {
        let sourceURL = URL(fileURLWithPath: "/tmp/source.txt")
        let playbackController = PlaybackControllerSpy()
        let recentDocuments = RecentDocumentManagerSpy()
        let viewModel = makeViewModel(
            playbackController: playbackController,
            recentDocuments: recentDocuments
        )

        await viewModel.loadVideo(url: sourceURL)

        XCTAssertTrue(playbackController.loadedURLs.isEmpty)
        XCTAssertTrue(recentDocuments.notedURLs.isEmpty)
        XCTAssertEqual(viewModel.state.lastError, SupportedVideoSource.unsupportedMessage)
    }

    func testClearRecentVideosClearsMenuState() {
        let recentURL = URL(fileURLWithPath: "/tmp/source.mov")
        let viewModel = makeViewModel(
            recentDocuments: RecentDocumentManagerSpy(recentDocumentURLs: [recentURL])
        )

        viewModel.clearRecentVideos()

        XCTAssertTrue(viewModel.recentVideoURLs.isEmpty)
    }

    private func makeViewModel(
        playbackController: PlaybackControlling = PlaybackControllerSpy(),
        recentDocuments: RecentDocumentManagerSpy = RecentDocumentManagerSpy()
    ) -> ClipperViewModel {
        ClipperViewModel(
            playbackController: playbackController,
            exporter: FixtureExporter(),
            tracer: RuntimeTraceStore(traceFileURL: makeTraceFileURL()),
            recentDocuments: recentDocuments
        )
    }

    private func makeTraceFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jsonl")
    }
}

@MainActor
private final class PlaybackControllerSpy: PlaybackControlling {
    let player = AVPlayer()
    var onSnapshot: ((PlaybackSnapshot) -> Void)?
    var loadedURLs: [URL] = []

    func loadVideo(url: URL) async throws -> VideoAssetContext {
        loadedURLs.append(url)
        return VideoAssetContext(
            url: url,
            duration: .clipperSeconds(60),
            frameDuration: .clipperSeconds(1.0 / 30.0)
        )
    }

    func setPlaying(_ isPlaying: Bool) {}

    func seek(to time: CMTime) {}
}

@MainActor
private final class RecentDocumentManagerSpy: RecentDocumentManaging {
    var recentDocumentURLs: [URL]
    private(set) var notedURLs: [URL] = []

    init(recentDocumentURLs: [URL] = []) {
        self.recentDocumentURLs = recentDocumentURLs
    }

    func noteRecentDocument(_ url: URL) {
        notedURLs.append(url)
        recentDocumentURLs.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        recentDocumentURLs.insert(url, at: 0)
    }

    func clearRecentDocuments() {
        recentDocumentURLs.removeAll()
    }
}
