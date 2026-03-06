import AVFoundation
import Foundation

struct AppLaunchOptions {
    let usesUITestFixture: Bool

    static var current: AppLaunchOptions {
        let arguments = ProcessInfo.processInfo.arguments
        return AppLaunchOptions(
            usesUITestFixture: arguments.contains("--ui-test-fixture")
        )
    }
}

enum AppViewModelFactory {
    @MainActor
    static func make() -> ClipperViewModel {
        let options = AppLaunchOptions.current
        let traceStore = RuntimeTraceStore(
            traceFileURL: FileManager.default.temporaryDirectory.appendingPathComponent("clipper-runtime-trace.jsonl")
        )

        if options.usesUITestFixture {
            let asset = VideoAssetContext(
                url: URL(fileURLWithPath: "/tmp/fixture.mov"),
                duration: .clipperSeconds(60),
                frameDuration: .clipperSeconds(1.0 / 30.0)
            )
            let first = ClipSegment(
                id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                start: .clipperSeconds(8),
                end: .clipperSeconds(15)
            )
            let second = ClipSegment(
                id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                start: .clipperSeconds(20),
                end: .clipperSeconds(28)
            )
            let initialState = EditorState(
                asset: asset,
                currentTime: .clipperSeconds(14),
                isPlaying: false,
                pendingInPoint: nil,
                clips: [first, second],
                selectedClipID: nil,
                exportPreset: .fastH264,
                lastError: nil
            )

            return ClipperViewModel(
                playbackController: FixturePlaybackController(asset: asset, currentTime: .clipperSeconds(14)),
                exporter: FixtureExporter(),
                tracer: traceStore,
                initialState: initialState
            )
        }

        return ClipperViewModel(
            playbackController: AVPlayerPlaybackController(),
            exporter: FFmpegClipExporter(tracer: traceStore),
            tracer: traceStore
        )
    }
}

@MainActor
final class FixturePlaybackController: PlaybackControlling {
    let player: AVPlayer
    var onSnapshot: ((PlaybackSnapshot) -> Void)?

    private let asset: VideoAssetContext
    private var currentTime: CMTime
    private var isPlaying = false

    init(asset: VideoAssetContext, currentTime: CMTime) {
        self.player = AVPlayer()
        self.asset = asset
        self.currentTime = currentTime
    }

    func loadVideo(url: URL) async throws -> VideoAssetContext {
        asset
    }

    func setPlaying(_ isPlaying: Bool) {
        self.isPlaying = isPlaying
        emitSnapshot()
    }

    func seek(to time: CMTime) {
        currentTime = time
        emitSnapshot()
    }

    private func emitSnapshot() {
        onSnapshot?(
            PlaybackSnapshot(
                url: asset.url,
                currentTime: currentTime,
                duration: asset.duration,
                frameDuration: asset.frameDuration,
                isPlaying: isPlaying
            )
        )
    }
}

struct FixtureExporter: ClipExporting {
    func export(sourceURL: URL, clips: [ClipSegment], outputDirectory: URL, preset: ExportPreset) async throws -> [URL] {
        clips.enumerated().map { offset, _ in
            outputDirectory.appendingPathComponent("fixture_clip_\(offset + 1)_\(preset.rawValue).mp4")
        }
    }
}
