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

    private let horizontalInset: CGFloat = 12
    private let trackHeight: CGFloat = 52
    private let segmentHeight: CGFloat = 36
    private let minimumSegmentWidth: CGFloat = 48
    private let rulerStepCount: Int = 4

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(0, geometry.size.width - (horizontalInset * 2))
            let layout = TimelineProjector.project(
                duration: duration,
                currentTime: currentTime,
                clips: clips,
                width: trackWidth
            )
            let ticks = makeRulerTicks(trackWidth: trackWidth)
            let playheadX = clampedPlayheadX(layout.playheadX, trackWidth: trackWidth)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(ticks) { tick in
                        Text(tick.label)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ConsolePalette.textSubtle)
                            .frame(maxWidth: .infinity, alignment: tick.alignment)
                    }
                }
                .padding(.horizontal, 2)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(trackBackground)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)

                    ForEach(ticks) { tick in
                        Rectangle()
                            .fill(tick.isTerminal ? ConsolePalette.highlight.opacity(0.22) : Color.white.opacity(0.05))
                            .frame(width: 1, height: trackHeight - 10)
                            .offset(x: tick.x + horizontalInset, y: 5)
                    }

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                        .frame(height: segmentHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .offset(x: horizontalInset, y: 8)

                    if let pendingFrame = pendingFrame(trackWidth: trackWidth) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ConsolePalette.pending.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        ConsolePalette.pending.opacity(0.42),
                                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                                    )
                            )
                            .frame(width: max(6, pendingFrame.width), height: segmentHeight)
                            .offset(x: pendingFrame.minX + horizontalInset, y: 8)
                    }

                    scrubSurface(trackWidth: trackWidth)
                        .offset(x: horizontalInset, y: 8)

                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        if layout.segments.indices.contains(index) {
                            let segment = layout.segments[index]
                            let segmentWidth = max(minimumSegmentWidth, segment.width)
                            let offsetX = min(segment.x, max(0, trackWidth - segmentWidth))

                            Button {
                                onSelectClip(clip.id)
                            } label: {
                                TimelineSegmentView(
                                    clipNumber: index + 1,
                                    clip: clip,
                                    isSelected: clip.id == selectedClipID,
                                    showsDuration: segmentWidth > 72
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(width: segmentWidth, height: segmentHeight)
                            .offset(x: offsetX + horizontalInset, y: 8)
                            .accessibilityLabel(
                                "Clip \(index + 1): \(TimecodeFormatter.displayString(for: clip.start)) to \(TimecodeFormatter.displayString(for: clip.end))"
                            )
                            .accessibilityIdentifier("clip-chip-\(index + 1)")
                        }
                    }

                    Capsule(style: .continuous)
                        .fill(ConsolePalette.playhead)
                        .frame(width: 3, height: trackHeight + 6)
                        .offset(x: playheadX + horizontalInset, y: -1)

                    Circle()
                        .fill(ConsolePalette.playhead)
                        .frame(width: 9, height: 9)
                        .offset(x: playheadX + horizontalInset - 3, y: 1)
                }
                .frame(height: trackHeight + 8)
            }
        }
        .frame(height: 84)
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

    private func scrubSurface(trackWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: trackWidth, height: segmentHeight)
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
        min(max(x, 0), max(0, trackWidth))
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
            height: segmentHeight
        )
    }

    private func makeRulerTicks(trackWidth: CGFloat) -> [TimelineTick] {
        let safeDuration = max(duration.secondsValue, 0)

        return (0...rulerStepCount).map { index in
            let ratio = CGFloat(index) / CGFloat(rulerStepCount)
            let seconds = safeDuration * Double(ratio)
            return TimelineTick(
                id: index,
                x: ratio * trackWidth,
                label: rulerLabel(for: seconds),
                alignment: index == 0 ? .leading : (index == rulerStepCount ? .trailing : .center),
                isTerminal: index == 0 || index == rulerStepCount
            )
        }
    }

    private func rulerLabel(for seconds: Double) -> String {
        let roundedSeconds = max(0, Int(seconds.rounded()))
        let hours = roundedSeconds / 3_600
        let minutes = (roundedSeconds % 3_600) / 60
        let remainingSeconds = roundedSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

private struct TimelineTick: Identifiable {
    let id: Int
    let x: CGFloat
    let label: String
    let alignment: Alignment
    let isTerminal: Bool
}

private struct TimelineSegmentView: View {
    let clipNumber: Int
    let clip: ClipSegment
    let isSelected: Bool
    let showsDuration: Bool

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
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
