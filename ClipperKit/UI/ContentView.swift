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
            let compactLayout = geometry.size.width < 1_220

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    commandDeck
                    workspace(compactLayout: compactLayout)
                    timelineConsole
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
            }
        }
        .background(ConsoleBackdrop())
        .background(
            KeyboardCaptureView(onKeyDown: viewModel.handle)
                .frame(width: 0, height: 0)
        )
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

    private var statusLabel: String {
        switch statusTone {
        case .idle:
            return "Idle"
        case .ready:
            return "Ready"
        case .marking:
            return "Marking"
        case .selection:
            return "Selection"
        case .exporting:
            return "Exporting"
        case .error:
            return "Error"
        }
    }

    private var clipCountLabel: String {
        "\(viewModel.state.clips.count) clip(s)"
    }

    private var commandDeck: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Clipper")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(ConsolePalette.textPrimary)

                Text("Precision clip review and export console")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ConsolePalette.textMuted)

                Text(sourceName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(ConsolePalette.textSubtle)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                ConsoleMetricPill(title: "State", value: statusLabel, emphasis: statusTone.emphasisColor)
                ClipCountPill(value: clipCountLabel)
            }

            Button("Open Video", action: viewModel.openVideo)
                .keyboardShortcut("o", modifiers: [.command])
                .buttonStyle(ConsoleButtonStyle(role: .secondary))
                .accessibilityIdentifier("open-video")

            Button(viewModel.isExporting ? "Exporting..." : "Export Clips", action: viewModel.exportClips)
                .buttonStyle(ConsoleButtonStyle(role: .primary))
                .disabled(!viewModel.state.canExport || viewModel.isExporting)
                .accessibilityIdentifier("export-clips")

            Button("Clear Clips", action: viewModel.clearClips)
                .buttonStyle(ConsoleButtonStyle(role: .secondary))
                .disabled(viewModel.state.clips.isEmpty)
        }
        .padding(20)
        .consolePanel(radius: 30)
    }

    @ViewBuilder
    private func workspace(compactLayout: Bool) -> some View {
        if compactLayout {
            VStack(spacing: 22) {
                playerColumn
                inspectorColumn
            }
        } else {
            HStack(alignment: .top, spacing: 22) {
                playerColumn
                    .frame(maxWidth: .infinity)

                inspectorColumn
                    .frame(width: 334)
            }
        }
    }

    private var playerColumn: some View {
        VStack(spacing: 22) {
            playerStage
            transportDeck
        }
    }

    private var playerStage: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Source Monitor")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textSubtle)
                        .textCase(.uppercase)

                    Text(sourceName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textPrimary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    ConsoleMetricPill(title: "Playhead", value: currentTimeString, emphasis: ConsolePalette.playhead)
                    ConsoleMetricPill(title: "Duration", value: durationString, emphasis: ConsolePalette.highlight)
                }
            }

            PlayerSurfaceView(player: viewModel.player, showsPlaceholder: !viewModel.hasLoadedVideo)
        }
        .padding(20)
        .consolePanel(radius: 34)
    }

    private var transportDeck: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transport")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textSubtle)
                        .textCase(.uppercase)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(currentTimeString)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(ConsolePalette.textPrimary)

                        Text("/")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(ConsolePalette.textSubtle)

                        Text(durationString)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(ConsolePalette.textMuted)
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusTone.emphasisColor)
                        .textCase(.uppercase)

                    Text(viewModel.statusMessage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(statusTone.messageColor)
                        .multilineTextAlignment(.leading)
                        .accessibilityLabel(viewModel.statusMessage)
                        .accessibilityIdentifier("status-message")
                }
                .frame(maxWidth: 360, alignment: .leading)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    TransportControlButton(title: "Frame -1", keyHint: "Shift Left") {
                        viewModel.stepBackwardFromUI()
                    }

                    TransportControlButton(title: "Back 5s", keyHint: "Left") {
                        viewModel.seekBackwardFromUI()
                    }

                    TransportControlButton(
                        title: viewModel.state.isPlaying ? "Pause" : "Play",
                        keyHint: "Space",
                        role: .primary
                    ) {
                        viewModel.togglePlaybackFromUI()
                    }

                    TransportControlButton(title: "Fwd 5s", keyHint: "Right") {
                        viewModel.seekForwardFromUI()
                    }

                    TransportControlButton(title: "Frame +1", keyHint: "Shift Right") {
                        viewModel.stepForwardFromUI()
                    }

                    TransportControlButton(title: "Mark In", keyHint: "I") {
                        viewModel.markInFromUI()
                    }

                    TransportControlButton(title: "Mark Out", keyHint: "O", role: .primary) {
                        viewModel.markOutFromUI()
                    }
                }
                .padding(.vertical, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ConsoleKeyLegend("Space", "Play/Pause")
                    ConsoleKeyLegend("Left / Right", "+/- 5 seconds")
                    ConsoleKeyLegend("Shift + Left / Right", "+/- 1 frame")
                    ConsoleKeyLegend("I / O", "Mark clip bounds")
                }
            }
        }
        .padding(20)
        .consolePanel(radius: 30)
    }

    private var inspectorColumn: some View {
        VStack(spacing: 22) {
            clipEditingPanel
            clipNavigatorPanel
            sessionPanel
            presetPanel
            diagnosticsPanel
        }
    }

    private var sessionPanel: some View {
        InspectorPanel(
            eyebrow: "Session",
            title: "Current Reel",
            detail: "One source at a time, clip ranges kept in source order."
        ) {
            VStack(spacing: 12) {
                ConsoleValueRow(label: "Source", value: sourceName)
                ConsoleValueRow(label: "Duration", value: durationString)
                ConsoleValueRow(label: "Selected Preset", value: viewModel.state.exportPreset.displayName)
                ConsoleValueRow(label: "Clips Queued", value: clipCountLabel)
            }
        }
    }

    private var presetPanel: some View {
        InspectorPanel(
            eyebrow: "Export",
            title: "Preset Bank",
            detail: "One preset defines the entire export run."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preset: \(viewModel.state.exportPreset.displayName)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(ConsolePalette.textPrimary)
                    .accessibilityLabel("Preset: \(viewModel.state.exportPreset.displayName)")
                    .accessibilityIdentifier("selected-export-preset")

                Text(viewModel.state.exportPreset.summary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ConsolePalette.textMuted)
                    .accessibilityLabel(viewModel.state.exportPreset.summary)
                    .accessibilityIdentifier("export-preset-summary")

                ForEach(ExportPreset.allCases) { preset in
                    PresetOptionCard(
                        preset: preset,
                        isSelected: viewModel.state.exportPreset == preset,
                        action: { viewModel.setExportPreset(preset) }
                    )
                    .accessibilityValue(viewModel.state.exportPreset == preset ? "selected" : "not selected")
                    .accessibilityIdentifier(preset.buttonIdentifier)
                }
            }
        }
    }

    private var clipNavigatorPanel: some View {
        InspectorPanel(
            eyebrow: "Clips",
            title: "Range Queue",
            detail: "Select a saved range here or directly on the timeline surface."
        ) {
            VStack(spacing: 10) {
                if viewModel.state.clips.isEmpty {
                    Text("No saved clips yet.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Press I to mark a start and O to commit the range.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ConsolePalette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(viewModel.state.clips.enumerated()), id: \.element.id) { index, clip in
                        Button {
                            viewModel.selectClip(clip.id)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("Clip \(index + 1)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(viewModel.state.selectedClipID == clip.id ? ConsolePalette.panelBase : ConsolePalette.textPrimary)

                                Spacer(minLength: 10)

                                Text("\(TimecodeFormatter.displayString(for: clip.start)) - \(TimecodeFormatter.displayString(for: clip.end))")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(viewModel.state.selectedClipID == clip.id ? ConsolePalette.panelBase.opacity(0.82) : ConsolePalette.textMuted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(viewModel.state.selectedClipID == clip.id ? AnyShapeStyle(ConsolePalette.accentPanel) : AnyShapeStyle(ConsolePalette.subpanelFill))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                viewModel.state.selectedClipID == clip.id ? ConsolePalette.highlight : ConsolePalette.subpanelStroke,
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("clip-chip-\(index + 1)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var clipEditingPanel: some View {
        if let selectedClip = viewModel.state.selectedClip {
            InspectorPanel(
                eyebrow: "Selection",
                title: "Clip Edit",
                detail: "Bind either edge of the selected range to the current playhead."
            ) {
                VStack(spacing: 12) {
                    ConsoleValueRow(label: "Start", value: TimecodeFormatter.displayString(for: selectedClip.start))
                    ConsoleValueRow(label: "End", value: TimecodeFormatter.displayString(for: selectedClip.end))
                    ConsoleValueRow(label: "Duration", value: TimecodeFormatter.displayString(for: selectedClip.duration))

                    VStack(spacing: 10) {
                        Button("Set Start To Playhead") {
                            viewModel.setSelectedClipBoundary(.start)
                        }
                        .buttonStyle(ConsoleButtonStyle(role: .secondary))
                        .accessibilityIdentifier("set-selected-start-to-playhead")

                        Button("Set End To Playhead") {
                            viewModel.setSelectedClipBoundary(.end)
                        }
                        .buttonStyle(ConsoleButtonStyle(role: .secondary))
                        .accessibilityIdentifier("set-selected-end-to-playhead")

                        Button("Delete Clip") {
                            viewModel.deleteSelectedClip()
                        }
                        .buttonStyle(ConsoleButtonStyle(role: .destructive))
                        .accessibilityIdentifier("delete-selected-clip")
                    }
                }
            }
        } else {
            InspectorPanel(
                eyebrow: "Selection",
                title: "Clip Edit",
                detail: "Select a clip block on the timeline to retime or remove it."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No clip selected.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textPrimary)

                    Text("Create a range with I and O, or click an existing segment in the timeline console.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ConsolePalette.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var diagnosticsPanel: some View {
        InspectorPanel(
            eyebrow: "Observability",
            title: "Diagnostics",
            detail: "Recent trace events are available without dominating the main workflow."
        ) {
            DisclosureGroup(isExpanded: $showsDiagnostics) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.traceFileURL.path)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(ConsolePalette.textSubtle)
                        .textSelection(.enabled)

                    if viewModel.recentTraceEvents.isEmpty {
                        Text("No trace events yet.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(ConsolePalette.textMuted)
                    } else {
                        ForEach(Array(viewModel.recentTraceEvents.suffix(6).reversed())) { event in
                            Text(event.displayLine)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(ConsolePalette.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text(showsDiagnostics ? "Hide Trace Feed" : "Show Trace Feed")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textPrimary)
                    Spacer(minLength: 8)
                    Text("\(viewModel.recentTraceEvents.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(ConsolePalette.textSubtle)
                }
            }
            .tint(ConsolePalette.highlight)
        }
    }

    private var timelineConsole: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Timeline Console")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textSubtle)
                        .textCase(.uppercase)

                    Text("Clip ribbon")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textPrimary)

                    Text("The red line is the live playhead. Click a segment to select it for inspection and retiming.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ConsolePalette.textMuted)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 6) {
                    ConsoleMetricPill(title: "Current", value: currentTimeString, emphasis: ConsolePalette.playhead)

                    if let pendingInPoint = viewModel.state.pendingInPoint {
                        ConsoleMetricPill(
                            title: "Pending In",
                            value: TimecodeFormatter.displayString(for: pendingInPoint),
                            emphasis: ConsolePalette.pending
                        )
                    }
                }
            }

            RibbonView(
                duration: viewModel.state.asset?.duration ?? .zero,
                currentTime: viewModel.state.currentTime,
                clips: viewModel.state.clips,
                selectedClipID: viewModel.state.selectedClipID,
                pendingInPoint: viewModel.state.pendingInPoint,
                onSelectClip: viewModel.selectClip
            )
        }
        .padding(20)
        .consolePanel(radius: 34)
    }
}

private enum ConsoleStatusTone {
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
    static let accentPanel = LinearGradient(
        colors: [
            Color(red: 0.356, green: 0.232, blue: 0.168).opacity(0.95),
            Color(red: 0.236, green: 0.164, blue: 0.125).opacity(0.98)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
}

private struct ConsoleButtonStyle: ButtonStyle {
    let role: ConsoleButtonRole

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(role == .primary ? ConsolePalette.panelBase : ConsolePalette.textPrimary)
            .frame(minWidth: 90)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(background(isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func background(isPressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(fillGradient(isPressed: isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
        }
    }
}

private struct TransportControlButton: View {
    let title: String
    let keyHint: String
    var role: ConsoleButtonRole = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(keyHint)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(role == .primary ? ConsolePalette.panelBase.opacity(0.8) : ConsolePalette.textSubtle)
            }
            .frame(width: 104, alignment: .leading)
        }
        .buttonStyle(ConsoleButtonStyle(role: role))
    }
}

private struct ConsoleMetricPill: View {
    let title: String
    let value: String
    let emphasis: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(ConsolePalette.textSubtle)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(ConsolePalette.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ConsolePalette.subpanelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(emphasis.opacity(0.55), lineWidth: 1)
                )
        )
    }
}

private struct ClipCountPill: View {
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clips")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(ConsolePalette.textSubtle)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(ConsolePalette.textPrimary)
                .lineLimit(1)
                .accessibilityLabel(value)
                .accessibilityIdentifier("clip-count")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ConsolePalette.subpanelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(ConsolePalette.highlight.opacity(0.55), lineWidth: 1)
                )
        )
    }
}

private struct ConsoleKeyLegend: View {
    let title: String
    let subtitle: String

    init(_ title: String, _ subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(ConsolePalette.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ConsolePalette.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(ConsolePalette.subpanelFill.opacity(0.9))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(ConsolePalette.subpanelStroke, lineWidth: 1)
                )
        )
    }
}

private struct InspectorPanel<Content: View>: View {
    let eyebrow: String
    let title: String
    let detail: String
    let content: Content

    init(
        eyebrow: String,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(ConsolePalette.textSubtle)
                    .textCase(.uppercase)

                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(ConsolePalette.textPrimary)

                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ConsolePalette.textMuted)
            }

            content
        }
        .padding(18)
        .consolePanel(radius: 28)
    }
}

private struct ConsoleValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(ConsolePalette.textSubtle)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(ConsolePalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ConsolePalette.subpanelFill.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(ConsolePalette.subpanelStroke, lineWidth: 1)
                )
        )
    }
}

private struct PresetOptionCard: View {
    let preset: ExportPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(preset.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textPrimary)

                    Spacer(minLength: 8)

                    if isSelected {
                        Text("Active")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(ConsolePalette.panelBase)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(ConsolePalette.highlight)
                            )
                    }
                }

                Text(preset.summary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ConsolePalette.textMuted)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isSelected ? AnyShapeStyle(ConsolePalette.accentPanel) : AnyShapeStyle(ConsolePalette.subpanelFill))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? ConsolePalette.highlight : ConsolePalette.subpanelStroke, lineWidth: 1)
            )
    }
}
