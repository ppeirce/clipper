import AVFoundation
import CoreGraphics
import Foundation

struct TimelineLayout: Equatable {
    struct Segment: Identifiable, Equatable {
        let id: UUID
        let x: CGFloat
        let width: CGFloat
    }

    let playheadX: CGFloat
    let segments: [Segment]
}

enum TimelineProjector {
    static func project(duration: CMTime, currentTime: CMTime, clips: [ClipSegment], width: CGFloat) -> TimelineLayout {
        guard width > 0, duration.secondsValue > 0 else {
            return TimelineLayout(playheadX: 0, segments: [])
        }

        let durationSeconds = duration.secondsValue
        let playheadRatio = min(max(currentTime.secondsValue / durationSeconds, 0), 1)
        let playheadX = CGFloat(playheadRatio) * width

        let segments = clips.map { clip in
            let x = CGFloat(clip.start.secondsValue / durationSeconds) * width
            let segmentWidth = CGFloat(clip.duration.secondsValue / durationSeconds) * width
            return TimelineLayout.Segment(id: clip.id, x: x, width: segmentWidth)
        }

        return TimelineLayout(playheadX: playheadX, segments: segments)
    }
}
