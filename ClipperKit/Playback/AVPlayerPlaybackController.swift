import AVFoundation
import Foundation

@MainActor
protocol PlaybackControlling: AnyObject {
    var player: AVPlayer { get }
    var onSnapshot: ((PlaybackSnapshot) -> Void)? { get set }

    func loadVideo(url: URL) async throws -> VideoAssetContext
    func setPlaying(_ isPlaying: Bool)
    func seek(to time: CMTime)
}

@MainActor
final class AVPlayerPlaybackController: PlaybackControlling {
    let player: AVPlayer
    var onSnapshot: ((PlaybackSnapshot) -> Void)?

    private var timeObserverToken: Any?
    private var assetContext: VideoAssetContext?

    init(player: AVPlayer = AVPlayer()) {
        self.player = player
        installPeriodicObserver()
    }

    func loadVideo(url: URL) async throws -> VideoAssetContext {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)
        let videoTracks = tracks.filter { $0.mediaType == .video }

        let nominalFrameRate: Float
        if let firstTrack = videoTracks.first {
            nominalFrameRate = (try? await firstTrack.load(.nominalFrameRate)) ?? 30
        } else {
            nominalFrameRate = 30
        }

        let safeFrameRate = nominalFrameRate > 0 ? Double(nominalFrameRate) : 30
        let frameDuration = CMTime.clipperSeconds(1.0 / safeFrameRate)
        let context = VideoAssetContext(url: url, duration: duration, frameDuration: frameDuration)

        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        player.pause()
        assetContext = context

        AppLogger.playback.info("Loaded \(url.lastPathComponent, privacy: .public)")
        emitSnapshot(currentTime: .zero, isPlaying: false)

        return context
    }

    func setPlaying(_ isPlaying: Bool) {
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
        emitSnapshot(currentTime: player.currentTime(), isPlaying: isPlaying)
    }

    func seek(to time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        emitSnapshot(currentTime: time, isPlaying: player.rate != 0)
    }

    private func installPeriodicObserver() {
        let interval = CMTime.clipperSeconds(1.0 / 30.0)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else {
                return
            }
            self.emitSnapshot(currentTime: time, isPlaying: self.player.rate != 0)
        }
    }

    private func emitSnapshot(currentTime: CMTime, isPlaying: Bool) {
        guard let assetContext else {
            return
        }

        onSnapshot?(
            PlaybackSnapshot(
                url: assetContext.url,
                currentTime: currentTime,
                duration: assetContext.duration,
                frameDuration: assetContext.frameDuration,
                isPlaying: isPlaying
            )
        )
    }
}
