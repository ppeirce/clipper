import AVFoundation
import Foundation

struct ClipSegment: Identifiable, Sendable {
    let id: UUID
    let start: CMTime
    let end: CMTime

    init(id: UUID = UUID(), start: CMTime, end: CMTime) {
        self.id = id
        self.start = start
        self.end = end
    }

    var duration: CMTime {
        CMTimeSubtract(end, start)
    }

    func normalized(maximumTime: CMTime) -> ClipSegment? {
        let clampedStart = start.clamped(lower: .zero, upper: maximumTime)
        let clampedEnd = end.clamped(lower: .zero, upper: maximumTime)
        guard CMTimeCompare(clampedEnd, clampedStart) > 0 else {
            return nil
        }
        return ClipSegment(id: id, start: clampedStart, end: clampedEnd)
    }
}

extension ClipSegment: Equatable {
    static func == (lhs: ClipSegment, rhs: ClipSegment) -> Bool {
        lhs.id == rhs.id &&
        lhs.start.isEqualTo(rhs.start) &&
        lhs.end.isEqualTo(rhs.end)
    }
}
