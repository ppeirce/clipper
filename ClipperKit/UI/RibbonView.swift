import AVFoundation
import SwiftUI

struct RibbonView: View {
    let duration: CMTime
    let currentTime: CMTime
    let clips: [ClipSegment]
    let selectedClipID: UUID?
    let pendingInPoint: CMTime?

    private let horizontalInset: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(0, geometry.size.width - (horizontalInset * 2))
            let layout = TimelineProjector.project(
                duration: duration,
                currentTime: currentTime,
                clips: clips,
                width: trackWidth
            )

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(nsColor: .controlBackgroundColor))

                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)

                if let pendingFrame = pendingFrame(trackWidth: trackWidth) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.25))
                        .frame(width: max(4, pendingFrame.width), height: 46)
                        .offset(x: pendingFrame.minX + horizontalInset)
                }

                ForEach(layout.segments) { segment in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(segment.id == selectedClipID ? Color.accentColor : Color.accentColor.opacity(0.7))
                        .frame(width: max(4, segment.width), height: 46)
                        .offset(x: segment.x + horizontalInset)
                }

                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 64)
                    .offset(x: min(max(layout.playheadX + horizontalInset, horizontalInset), trackWidth + horizontalInset))
            }
        }
        .frame(height: 86)
    }

    private func pendingFrame(trackWidth: CGFloat) -> CGRect? {
        guard let pendingInPoint, duration.secondsValue > 0 else {
            return nil
        }

        let start = min(pendingInPoint.secondsValue, currentTime.secondsValue)
        let end = max(pendingInPoint.secondsValue, currentTime.secondsValue)
        let durationSeconds = duration.secondsValue

        return CGRect(
            x: CGFloat(start / durationSeconds) * trackWidth,
            y: 0,
            width: CGFloat((end - start) / durationSeconds) * trackWidth,
            height: 46
        )
    }
}
