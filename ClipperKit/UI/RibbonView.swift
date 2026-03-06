import AVFoundation
import SwiftUI

struct RibbonView: View {
    let duration: CMTime
    let currentTime: CMTime
    let clips: [ClipSegment]
    let selectedClipID: UUID?
    let pendingInPoint: CMTime?
    let onSelectClip: (UUID?) -> Void
    let onScrub: (CMTime) -> Void
    let onScrubEnd: (CMTime) -> Void

    private let trackHeight: CGFloat = 40
    private let segmentHeight: CGFloat = 28
    private let minimumSegmentWidth: CGFloat = 48
    private let segmentCornerRadius: CGFloat = 12
    private let trackVerticalInset: CGFloat = 6
    private let playheadLineWidth: CGFloat = 3
    private let playheadHandleSize: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(0, geometry.size.width)
            let layout = TimelineProjector.project(
                duration: duration,
                currentTime: currentTime,
                clips: clips,
                width: trackWidth
            )
            let playheadX = clampedPlayheadX(layout.playheadX, trackWidth: trackWidth)

            track(
                trackWidth: trackWidth,
                layout: layout,
                playheadX: playheadX
            )
        }
        .frame(height: trackHeight)
    }

    private func track(trackWidth: CGFloat, layout: TimelineLayout, playheadX: CGFloat) -> some View {
        let trackShape = Rectangle()

        return ZStack(alignment: .topLeading) {
            trackShape
                .fill(trackBackground)

            ZStack(alignment: .topLeading) {
                trackBed(trackWidth: trackWidth)
                pendingRangeLayer(trackWidth: trackWidth)
                scrubSurface(trackWidth: trackWidth)
                clipLayer(trackWidth: trackWidth, layout: layout)
                playheadLayer(playheadX: playheadX)
            }
            .frame(width: trackWidth, height: trackHeight, alignment: .topLeading)
            .clipShape(trackShape)

            trackShape
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
        .frame(width: trackWidth, height: trackHeight, alignment: .topLeading)
        .contentShape(trackShape)
    }

    private func trackBed(trackWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.03))
            .overlay(
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            )
            .frame(width: trackWidth, height: segmentHeight, alignment: .leading)
            .offset(y: trackVerticalInset)
    }

    @ViewBuilder
    private func pendingRangeLayer(trackWidth: CGFloat) -> some View {
        if let pendingFrame = pendingFrame(trackWidth: trackWidth) {
            Rectangle()
                .fill(ConsolePalette.pending.opacity(0.15))
                .overlay(
                    Rectangle()
                        .strokeBorder(
                            ConsolePalette.pending.opacity(0.42),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                )
                .frame(width: max(6, pendingFrame.width), height: segmentHeight)
                .position(
                    x: pendingFrame.minX + (pendingFrame.width / 2),
                    y: trackVerticalInset + (segmentHeight / 2)
                )
        }
    }

    private func scrubSurface(trackWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: trackWidth, height: segmentHeight)
            .offset(y: trackVerticalInset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onScrub(time(for: value.location.x, trackWidth: trackWidth))
                    }
                    .onEnded { value in
                        onScrubEnd(time(for: value.location.x, trackWidth: trackWidth))
                    }
            )
    }

    private func clipLayer(trackWidth: CGFloat, layout: TimelineLayout) -> some View {
        ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
            if layout.segments.indices.contains(index) {
                let segment = layout.segments[index]
                let segmentWidth = min(max(minimumSegmentWidth, segment.width), trackWidth)
                let minX = min(max(0, segment.x), max(0, trackWidth - segmentWidth))

                Button {
                    onSelectClip(clip.id)
                } label: {
                    TimelineSegmentView(
                        clipNumber: index + 1,
                        clip: clip,
                        isSelected: clip.id == selectedClipID,
                        showsDuration: segmentWidth > 72,
                        cornerRadius: segmentCornerRadius
                    )
                }
                .buttonStyle(.plain)
                .frame(width: segmentWidth, height: segmentHeight)
                .position(
                    x: minX + (segmentWidth / 2),
                    y: trackVerticalInset + (segmentHeight / 2)
                )
                .accessibilityLabel(
                    "Clip \(index + 1): \(TimecodeFormatter.displayString(for: clip.start)) to \(TimecodeFormatter.displayString(for: clip.end))"
                )
                .accessibilityIdentifier("clip-chip-\(index + 1)")
            }
        }
    }

    private func playheadLayer(playheadX: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Capsule(style: .continuous)
                .fill(ConsolePalette.playhead)
                .frame(width: playheadLineWidth, height: trackHeight - 4)
                .position(x: playheadX, y: trackHeight / 2)

            Circle()
                .fill(ConsolePalette.playhead)
                .frame(width: playheadHandleSize, height: playheadHandleSize)
                .position(x: playheadX, y: 6)
        }
    }

    private var trackBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.28),
                Color(red: 0.09, green: 0.1, blue: 0.12),
                Color.black.opacity(0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func time(for locationX: CGFloat, trackWidth: CGFloat) -> CMTime {
        guard duration.secondsValue > 0, trackWidth > 0 else {
            return .zero
        }

        let clampedX = min(max(locationX, 0), trackWidth)
        let ratio = Double(clampedX / trackWidth)
        let seconds = duration.secondsValue * ratio
        return CMTime.clipperSeconds(seconds)
    }

    private func clampedPlayheadX(_ x: CGFloat, trackWidth: CGFloat) -> CGFloat {
        let halfLine = playheadLineWidth / 2
        let halfHandle = playheadHandleSize / 2
        let inset = max(halfLine, halfHandle)
        return min(max(x, inset), max(inset, trackWidth - inset))
    }

    private func pendingFrame(trackWidth: CGFloat) -> CGRect? {
        guard let pendingInPoint, duration.secondsValue > 0 else {
            return nil
        }

        let start = min(pendingInPoint.secondsValue, currentTime.secondsValue)
        let end = max(pendingInPoint.secondsValue, currentTime.secondsValue)
        let durationSeconds = duration.secondsValue
        let minX = min(CGFloat(start / durationSeconds) * trackWidth, trackWidth)
        let width = min(
            CGFloat((end - start) / durationSeconds) * trackWidth,
            max(0, trackWidth - minX)
        )

        return CGRect(
            x: minX,
            y: 0,
            width: width,
            height: segmentHeight
        )
    }

}

private struct TimelineSegmentView: View {
    let clipNumber: Int
    let clip: ClipSegment
    let isSelected: Bool
    let showsDuration: Bool
    let cornerRadius: CGFloat

    var body: some View {
        HStack(spacing: 5) {
            Text("\(clipNumber)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(labelColor)

            if showsDuration {
                Text(TimecodeFormatter.displayString(for: clip.duration))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var labelColor: Color {
        isSelected ? ConsolePalette.panelBase : ConsolePalette.textPrimary
    }

    private var detailColor: Color {
        isSelected ? ConsolePalette.panelBase.opacity(0.84) : ConsolePalette.textMuted
    }

    private var borderColor: Color {
        isSelected ? ConsolePalette.highlight.opacity(0.9) : ConsolePalette.subpanelStroke
    }

    private var background: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        ConsolePalette.highlight,
                        ConsolePalette.buttonPrimaryBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(ConsolePalette.subpanelFill.opacity(0.95))
    }
}
