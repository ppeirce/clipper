import AVFoundation
import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel: ClipperViewModel
    @State private var showsDiagnostics = false

    public init() {
        _viewModel = StateObject(wrappedValue: AppViewModelFactory.make())
    }

    init(viewModel: ClipperViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        GeometryReader { geometry in
            let shouldScroll = geometry.size.height < 820 || geometry.size.width < 980

            Group {
                if shouldScroll {
                    ScrollView(.vertical, showsIndicators: false) {
                        mainLayout(in: geometry)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                } else {
                    mainLayout(in: geometry)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .background(ConsoleBackdrop())
        .background(
            KeyboardCaptureView(onKeyDown: viewModel.handle)
                .frame(width: 0, height: 0)
        )
    }

    @ViewBuilder
    private func mainLayout(in geometry: GeometryProxy) -> some View {
        let playerHeight = min(max(geometry.size.height * 0.62, 320), 760)

        VStack(spacing: 12) {
            utilityBar(compact: geometry.size.width < 1_180)
            playerConsole(playerHeight: playerHeight)

            if showsDiagnostics {
                diagnosticsDrawer
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: showsDiagnostics)
        .padding(16)
    }

    private var sourceName: String {
        viewModel.state.asset?.url.lastPathComponent ?? "No source loaded"
    }

    private var currentTimeString: String {
        TimecodeFormatter.displayString(for: viewModel.state.currentTime)
    }

    private var durationString: String {
        guard let asset = viewModel.state.asset else {
            return "--:--:--.---"
        }
        return TimecodeFormatter.displayString(for: asset.duration)
    }

    private var clipCountLabel: String {
        "\(viewModel.state.clips.count) clip(s)"
    }

    private var statusTone: ConsoleStatusTone {
        if viewModel.state.lastError != nil {
            return .error
        }
        if viewModel.isExporting {
            return .exporting
        }
        if viewModel.state.pendingInPoint != nil {
            return .marking
        }
        if viewModel.state.selectedClip != nil {
            return .selection
        }
        if viewModel.state.asset != nil {
            return .ready
        }
        return .idle
    }

    private var statusShortLabel: String {
        switch statusTone {
        case .idle:
            return "Idle"
        case .ready:
            return "Ready"
        case .marking:
            return "In"
        case .selection:
            return "Clip"
        case .exporting:
            return "Export"
        case .error:
            return "Error"
        }
    }

    @ViewBuilder
    private func utilityBar(compact: Bool) -> some View {
        if compact {
            VStack(alignment: .leading, spacing: 10) {
                utilityHeader
                utilityActions
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .consolePanel(radius: 22)
        } else {
            HStack(spacing: 12) {
                utilityHeader
                Spacer(minLength: 12)
                utilityActions
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .consolePanel(radius: 22)
        }
    }

    private var utilityHeader: some View {
        HStack(spacing: 10) {
            Text("Clipper")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ConsolePalette.textPrimary)

            Text(sourceName)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(ConsolePalette.textMuted)
                .lineLimit(1)

            StatusToken(label: statusShortLabel, tone: statusTone)

            Text(viewModel.statusMessage)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(statusTone.messageColor)
                .lineLimit(1)
                .accessibilityLabel(viewModel.statusMessage)
                .accessibilityIdentifier("status-message")
        }
    }

    private var utilityActions: some View {
        HStack(spacing: 8) {
            CountBadge(value: clipCountLabel)

            presetMenu

            Button("Open", action: viewModel.openVideo)
                .keyboardShortcut("o", modifiers: [.command])
                .buttonStyle(ConsoleButtonStyle(role: .secondary, compact: true))
                .accessibilityIdentifier("open-video")

            Button(viewModel.isExporting ? "Exporting..." : "Export", action: viewModel.exportClips)
                .buttonStyle(ConsoleButtonStyle(role: .primary, compact: true))
                .disabled(!viewModel.state.canExport || viewModel.isExporting)
                .accessibilityIdentifier("export-clips")

            Menu {
                Button(showsDiagnostics ? "Hide Diagnostics" : "Show Diagnostics") {
                    showsDiagnostics.toggle()
                }

                Divider()

                Button("Clear Clips", action: viewModel.clearClips)
                    .disabled(viewModel.state.clips.isEmpty)
            } label: {
                Text("More")
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(ConsoleButtonStyle(role: .secondary, compact: true))
        }
    }

    private var presetMenu: some View {
        Menu {
            ForEach(ExportPreset.allCases) { preset in
                Button {
                    viewModel.setExportPreset(preset)
                } label: {
                    HStack {
                        Text(preset.displayName)
                        if viewModel.state.exportPreset == preset {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityIdentifier(preset.buttonIdentifier)
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.state.exportPreset.displayName)
                    .lineLimit(1)
                    .accessibilityLabel("Preset: \(viewModel.state.exportPreset.displayName)")
                    .accessibilityIdentifier("selected-export-preset")

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(ConsoleButtonStyle(role: .secondary, compact: true))
        .help(viewModel.state.exportPreset.summary)
    }

    private func playerConsole(playerHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            PlayerSurfaceView(player: viewModel.player, showsPlaceholder: !viewModel.hasLoadedVideo)
                .frame(height: playerHeight)
                .overlay(alignment: .topLeading) {
                    playerOverlay
                        .padding(12)
                }

            CompactRail(
                currentTime: currentTimeString,
                duration: durationString,
                isPlaying: viewModel.state.isPlaying,
                durationTime: viewModel.state.asset?.duration ?? .zero,
                currentTimeValue: viewModel.state.currentTime,
                clips: viewModel.state.clips,
                selectedClipID: viewModel.state.selectedClipID,
                pendingInPoint: viewModel.state.pendingInPoint,
                selectedClip: viewModel.state.selectedClip,
                selectedClipIndex: viewModel.state.selectedClipIndex,
                onPlayPause: viewModel.togglePlaybackFromUI,
                onSeekBackward: viewModel.seekBackwardFromUI,
                onSeekForward: viewModel.seekForwardFromUI,
                onStepBackward: viewModel.stepBackwardFromUI,
                onStepForward: viewModel.stepForwardFromUI,
                onMarkIn: viewModel.markInFromUI,
                onMarkOut: viewModel.markOutFromUI,
                onSelectClip: viewModel.selectClip,
                onScrub: viewModel.scrubToTimeFromUI,
                onScrubEnd: viewModel.commitScrubToTimeFromUI,
                onSetSelectedStart: { viewModel.setSelectedClipBoundary(.start) },
                onSetSelectedEnd: { viewModel.setSelectedClipBoundary(.end) },
                onDeleteSelectedClip: viewModel.deleteSelectedClip
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .consolePanel(radius: 28)
    }

    private var playerOverlay: some View {
        HStack(spacing: 8) {
            OverlayBadge(label: currentTimeString, emphasis: ConsolePalette.playhead)
            OverlayBadge(label: durationString, emphasis: ConsolePalette.highlight)

            if let pendingInPoint = viewModel.state.pendingInPoint {
                OverlayBadge(
                    label: "IN \(TimecodeFormatter.displayString(for: pendingInPoint))",
                    emphasis: ConsolePalette.pending
                )
            }
        }
    }

    private var diagnosticsDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Diagnostics")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(ConsolePalette.textPrimary)

                Text(viewModel.traceFileURL.path)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(ConsolePalette.textSubtle)
                    .lineLimit(1)
                    .textSelection(.enabled)

                Spacer(minLength: 10)

                Button("Hide") {
                    showsDiagnostics = false
                }
                .buttonStyle(ConsoleButtonStyle(role: .secondary, compact: true))
            }

            if viewModel.recentTraceEvents.isEmpty {
                Text("No trace events yet.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ConsolePalette.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(viewModel.recentTraceEvents.suffix(6).reversed())) { event in
                        Text(event.displayLine)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(ConsolePalette.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(14)
        .consolePanel(radius: 22)
    }
}

private struct CompactRail: View {
    let currentTime: String
    let duration: String
    let isPlaying: Bool
    let durationTime: CMTime
    let currentTimeValue: CMTime
    let clips: [ClipSegment]
    let selectedClipID: UUID?
    let pendingInPoint: CMTime?
    let selectedClip: ClipSegment?
    let selectedClipIndex: Int?
    let onPlayPause: () -> Void
    let onSeekBackward: () -> Void
    let onSeekForward: () -> Void
    let onStepBackward: () -> Void
    let onStepForward: () -> Void
    let onMarkIn: () -> Void
    let onMarkOut: () -> Void
    let onSelectClip: (UUID?) -> Void
    let onScrub: (CMTime) -> Void
    let onScrubEnd: (CMTime) -> Void
    let onSetSelectedStart: () -> Void
    let onSetSelectedEnd: () -> Void
    let onDeleteSelectedClip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RailButton(label: "-1f", action: onStepBackward)
                RailButton(label: "-5s", action: onSeekBackward)
                RailButton(label: isPlaying ? "Pause" : "Play", role: .primary, action: onPlayPause)
                RailButton(label: "+5s", action: onSeekForward)
                RailButton(label: "+1f", action: onStepForward)

                Spacer(minLength: 8)

                Text(currentTime)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(ConsolePalette.textPrimary)

                Text("/")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ConsolePalette.textSubtle)

                Text(duration)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(ConsolePalette.textMuted)

                Spacer(minLength: 8)

                RailButton(label: "I", role: pendingInPoint == nil ? .secondary : .accent, action: onMarkIn)
                RailButton(label: "O", role: .primary, action: onMarkOut)
            }

            RibbonView(
                duration: durationTime,
                currentTime: currentTimeValue,
                clips: clips,
                selectedClipID: selectedClipID,
                pendingInPoint: pendingInPoint,
                onSelectClip: onSelectClip,
                onScrub: onScrub,
                onScrubEnd: onScrubEnd
            )

            if let selectedClip {
                HStack(spacing: 8) {
                    SelectionBadge(index: selectedClipIndex.map { $0 + 1 }, clip: selectedClip)

                    RailButton(label: "Set In", action: onSetSelectedStart)
                        .accessibilityIdentifier("set-selected-start-to-playhead")

                    RailButton(label: "Set Out", action: onSetSelectedEnd)
                        .accessibilityIdentifier("set-selected-end-to-playhead")

                    RailButton(label: "Delete", role: .destructive, action: onDeleteSelectedClip)
                        .accessibilityIdentifier("delete-selected-clip")

                    Spacer(minLength: 0)
                }
            } else if let pendingInPoint {
                HStack(spacing: 8) {
                    PendingBadge(
                        start: TimecodeFormatter.displayString(for: pendingInPoint),
                        end: currentTime
                    )
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    ConsolePalette.panelBase.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }
}

private enum ConsoleStatusTone: Equatable {
    case idle
    case ready
    case marking
    case selection
    case exporting
    case error

    var emphasisColor: Color {
        switch self {
        case .idle:
            return ConsolePalette.textSubtle
        case .ready:
            return ConsolePalette.highlight
        case .marking:
            return ConsolePalette.pending
        case .selection:
            return ConsolePalette.highlight
        case .exporting:
            return ConsolePalette.highlight
        case .error:
            return ConsolePalette.error
        }
    }

    var messageColor: Color {
        switch self {
        case .error:
            return ConsolePalette.error
        case .idle:
            return ConsolePalette.textMuted
        default:
            return ConsolePalette.textPrimary
        }
    }
}

enum ConsolePalette {
    static let backdropTop = Color(red: 0.105, green: 0.117, blue: 0.137)
    static let backdropBottom = Color(red: 0.055, green: 0.062, blue: 0.074)
    static let backdropBloom = Color(red: 0.33, green: 0.21, blue: 0.16).opacity(0.22)

    static let panelTop = Color(red: 0.135, green: 0.15, blue: 0.176)
    static let panelBottom = Color(red: 0.095, green: 0.107, blue: 0.127)
    static let panelBase = Color(red: 0.102, green: 0.113, blue: 0.131)
    static let panelStroke = Color.white.opacity(0.08)
    static let panelGlow = Color.black.opacity(0.34)

    static let subpanelFill = Color(red: 0.122, green: 0.134, blue: 0.156)
    static let subpanelStroke = Color.white.opacity(0.06)

    static let textPrimary = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let textMuted = Color(red: 0.76, green: 0.79, blue: 0.82)
    static let textSubtle = Color(red: 0.58, green: 0.63, blue: 0.68)

    static let highlight = Color(red: 0.93, green: 0.69, blue: 0.45)
    static let playhead = Color(red: 0.93, green: 0.29, blue: 0.24)
    static let pending = Color(red: 0.98, green: 0.55, blue: 0.24)
    static let error = Color(red: 0.92, green: 0.35, blue: 0.31)

    static let buttonPrimaryTop = Color(red: 0.93, green: 0.69, blue: 0.45)
    static let buttonPrimaryBottom = Color(red: 0.76, green: 0.48, blue: 0.29)
    static let buttonSecondaryTop = Color(red: 0.18, green: 0.2, blue: 0.236)
    static let buttonSecondaryBottom = Color(red: 0.13, green: 0.145, blue: 0.174)
    static let buttonDestructiveTop = Color(red: 0.61, green: 0.20, blue: 0.18)
    static let buttonDestructiveBottom = Color(red: 0.41, green: 0.14, blue: 0.13)

    static let backgroundGradient = LinearGradient(
        colors: [backdropTop, backdropBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panelGradient = LinearGradient(
        colors: [panelTop, panelBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct ConsoleBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ConsolePalette.backgroundGradient

                RadialGradient(
                    colors: [ConsolePalette.backdropBloom, .clear],
                    center: .topLeading,
                    startRadius: 40,
                    endRadius: max(geometry.size.width * 0.55, 320)
                )
                .blendMode(.screen)

                Path { path in
                    stride(from: 0, through: geometry.size.width, by: 56).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }

                    stride(from: 0, through: geometry.size.height, by: 56).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.025), lineWidth: 0.8)
            }
            .ignoresSafeArea()
        }
    }
}

private struct ConsolePanelModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(ConsolePalette.panelGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(ConsolePalette.panelStroke, lineWidth: 1)
                    )
                    .shadow(color: ConsolePalette.panelGlow, radius: 18, x: 0, y: 12)
            )
    }
}

private extension View {
    func consolePanel(radius: CGFloat = 28) -> some View {
        modifier(ConsolePanelModifier(radius: radius))
    }
}

private enum ConsoleButtonRole {
    case primary
    case secondary
    case destructive
    case accent
}

private struct ConsoleButtonStyle: ButtonStyle {
    let role: ConsoleButtonRole
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .frame(minWidth: compact ? 0 : 90)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 8 : 11)
            .background(background(isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch role {
        case .primary, .accent:
            return ConsolePalette.panelBase
        case .secondary, .destructive:
            return ConsolePalette.textPrimary
        }
    }

    private func background(isPressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: compact ? 13 : 16, style: .continuous)
            .fill(fillGradient(isPressed: isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 13 : 16, style: .continuous)
                    .strokeBorder(borderColor(isPressed: isPressed), lineWidth: 1)
            )
    }

    private func fillGradient(isPressed: Bool) -> LinearGradient {
        switch role {
        case .primary:
            return LinearGradient(
                colors: [
                    ConsolePalette.buttonPrimaryTop.opacity(isPressed ? 0.82 : 1),
                    ConsolePalette.buttonPrimaryBottom.opacity(isPressed ? 0.82 : 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            return LinearGradient(
                colors: [
                    ConsolePalette.buttonSecondaryTop.opacity(isPressed ? 0.86 : 1),
                    ConsolePalette.buttonSecondaryBottom.opacity(isPressed ? 0.86 : 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .destructive:
            return LinearGradient(
                colors: [
                    ConsolePalette.buttonDestructiveTop.opacity(isPressed ? 0.84 : 1),
                    ConsolePalette.buttonDestructiveBottom.opacity(isPressed ? 0.84 : 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .accent:
            return LinearGradient(
                colors: [
                    ConsolePalette.pending.opacity(isPressed ? 0.84 : 1),
                    ConsolePalette.highlight.opacity(isPressed ? 0.84 : 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func borderColor(isPressed: Bool) -> Color {
        switch role {
        case .primary:
            return ConsolePalette.highlight.opacity(isPressed ? 0.45 : 0.65)
        case .secondary:
            return Color.white.opacity(isPressed ? 0.05 : 0.09)
        case .destructive:
            return ConsolePalette.error.opacity(isPressed ? 0.35 : 0.55)
        case .accent:
            return ConsolePalette.pending.opacity(isPressed ? 0.4 : 0.6)
        }
    }
}

private struct RailButton: View {
    let label: String
    var role: ConsoleButtonRole = .secondary
    let action: () -> Void

    var body: some View {
        Button(label, action: action)
            .buttonStyle(ConsoleButtonStyle(role: role, compact: true))
    }
}

private struct StatusToken: View {
    let label: String
    let tone: ConsoleStatusTone

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tone == .error ? ConsolePalette.textPrimary : tone.emphasisColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill((tone == .error ? ConsolePalette.error : tone.emphasisColor).opacity(0.16))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(tone.emphasisColor.opacity(0.36), lineWidth: 1)
                    )
            )
    }
}

private struct CountBadge: View {
    let value: String

    var body: some View {
        Text(value)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(ConsolePalette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(ConsolePalette.subpanelFill)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(ConsolePalette.highlight.opacity(0.45), lineWidth: 1)
                    )
            )
            .accessibilityLabel(value)
            .accessibilityIdentifier("clip-count")
    }
}

private struct OverlayBadge: View {
    let label: String
    let emphasis: Color

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(ConsolePalette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.44))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(emphasis.opacity(0.5), lineWidth: 1)
                    )
            )
    }
}

private struct SelectionBadge: View {
    let index: Int?
    let clip: ClipSegment

    var body: some View {
        HStack(spacing: 8) {
            Text(index.map { "C\($0)" } ?? "Clip")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ConsolePalette.panelBase)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(ConsolePalette.highlight)
                )

            Text("\(TimecodeFormatter.displayString(for: clip.start)) - \(TimecodeFormatter.displayString(for: clip.end))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ConsolePalette.textPrimary)
                .lineLimit(1)

            Text(TimecodeFormatter.displayString(for: clip.duration))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ConsolePalette.textMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(ConsolePalette.subpanelFill)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(ConsolePalette.subpanelStroke, lineWidth: 1)
                )
        )
    }
}

private struct PendingBadge: View {
    let start: String
    let end: String

    var body: some View {
        HStack(spacing: 8) {
            Text("IN")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ConsolePalette.panelBase)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(ConsolePalette.pending)
                )

            Text(start)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ConsolePalette.textPrimary)

            Text("→")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ConsolePalette.textSubtle)

            Text(end)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ConsolePalette.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(ConsolePalette.subpanelFill)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(ConsolePalette.pending.opacity(0.4), lineWidth: 1)
                )
        )
    }
}
