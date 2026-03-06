import AVFoundation
import SwiftUI

struct RibbonView: View {
    let duration: CMTime
    let currentTime: CMTime
    let clips: [ClipSegment]
    let selectedClipID: UUID?
    let pendingInPoint: CMTime?
    let onSelectClip: (UUID?) -> Void

    private let horizontalInset: CGFloat = 18
    private let trackHeight: CGFloat = 96
    private let segmentHeight: CGFloat = 58
    private let minimumSegmentWidth: CGFloat = 78
    private let rulerStepCount: Int = 5

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(0, geometry.size.width - (horizontalInset * 2))
            let layout = TimelineProjector.project(
                duration: duration,
                currentTime: currentTime,
                clips: clips,
                width: trackWidth
            )
            let rulerTicks = makeRulerTicks(trackWidth: trackWidth)
            let playheadX = clampedPlayheadX(layout.playheadX, trackWidth: trackWidth)

            VStack(alignment: .leading, spacing: 12) {
                ruler(ticks: rulerTicks)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(trackBackground)

                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)

                    ForEach(rulerTicks) { tick in
                        Rectangle()
                            .fill(tick.isTerminal ? ConsolePalette.highlight.opacity(0.22) : Color.white.opacity(0.05))
                            .frame(width: 1, height: trackHeight - 12)
                            .offset(x: tick.x + horizontalInset, y: 6)
                    }

                    trackGuide
                        .offset(x: horizontalInset, y: 18)

                    if let pendingFrame = pendingFrame(trackWidth: trackWidth) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(ConsolePalette.pending.opacity(0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(
                                        ConsolePalette.pending.opacity(0.46),
                                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                                    )
                            )
                            .frame(width: max(8, pendingFrame.width), height: segmentHeight)
                            .offset(x: pendingFrame.minX + horizontalInset, y: 18)
                    }

                    if clips.isEmpty {
                        VStack(spacing: 8) {
                            Text(duration.secondsValue > 0 ? "Mark a range to populate the ribbon." : "Load a source to activate the ribbon.")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(ConsolePalette.textMuted)

                            Text("The playhead remains live even before clips exist.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(ConsolePalette.textSubtle)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
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
                                        showsExpandedDetail: segmentWidth > 132
                                    )
                                }
                                .buttonStyle(.plain)
                                .frame(width: segmentWidth, height: segmentHeight)
                                .offset(x: offsetX + horizontalInset, y: 18)
                                .accessibilityLabel(
                                    "Clip \(index + 1): \(TimecodeFormatter.displayString(for: clip.start)) to \(TimecodeFormatter.displayString(for: clip.end))"
                                )
                                .accessibilityIdentifier("timeline-clip-segment-\(index + 1)")
                            }
                        }
                    }

                    Capsule(style: .continuous)
                        .fill(ConsolePalette.playhead)
                        .frame(width: 3, height: trackHeight + 8)
                        .offset(x: playheadX + horizontalInset, y: -2)

                    Circle()
                        .fill(ConsolePalette.playhead)
                        .frame(width: 10, height: 10)
                        .offset(x: playheadX + horizontalInset - 3.5, y: 2)
                }
                .frame(height: trackHeight + 18)

                HStack {
                    Text("Start")
                    Spacer()
                    Text("Playhead \(TimecodeFormatter.displayString(for: currentTime))")
                    Spacer()
                    Text(duration.secondsValue > 0 ? "End" : "Awaiting source")
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ConsolePalette.textSubtle)
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 182)
    }

    private var trackBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.3),
                Color(red: 0.09, green: 0.1, blue: 0.12),
                Color.black.opacity(0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var trackGuide: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .frame(height: segmentHeight)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                .frame(height: segmentHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ruler(ticks: [TimelineTick]) -> some View {
        HStack(spacing: 0) {
            ForEach(ticks) { tick in
                Text(tick.label)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ConsolePalette.textSubtle)
                    .frame(maxWidth: .infinity, alignment: tick.alignment)
            }
        }
        .padding(.horizontal, 2)
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
    let showsExpandedDetail: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Clip \(clipNumber)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(labelColor)

                Spacer(minLength: 6)

                Text(TimecodeFormatter.displayString(for: clip.duration))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }

            if showsExpandedDetail {
                Text("\(TimecodeFormatter.displayString(for: clip.start)) - \(TimecodeFormatter.displayString(for: clip.end))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            } else {
                Text("Select for edit")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
        )
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isSelected ? selectedFill : baseFill,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var selectedFill: [Color] {
        [
            ConsolePalette.highlight.opacity(0.96),
            Color(red: 0.67, green: 0.39, blue: 0.22)
        ]
    }

    private var baseFill: [Color] {
        [
            Color(red: 0.27, green: 0.31, blue: 0.36),
            Color(red: 0.18, green: 0.21, blue: 0.25)
        ]
    }

    private var borderColor: Color {
        isSelected ? ConsolePalette.highlight.opacity(0.75) : Color.white.opacity(0.08)
    }

    private var labelColor: Color {
        isSelected ? ConsolePalette.panelBase : ConsolePalette.textPrimary
    }

    private var detailColor: Color {
        isSelected ? ConsolePalette.panelBase.opacity(0.86) : ConsolePalette.textMuted
    }
}
