import AVFoundation
import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel: ClipperViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: AppViewModelFactory.make())
    }

    init(viewModel: ClipperViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 18) {
            header
            PlayerSurfaceView(player: viewModel.player, showsPlaceholder: !viewModel.hasLoadedVideo)
            RibbonView(
                duration: viewModel.state.asset?.duration ?? .zero,
                currentTime: viewModel.state.currentTime,
                clips: viewModel.state.clips,
                selectedClipID: viewModel.state.selectedClipID,
                pendingInPoint: viewModel.state.pendingInPoint
            )
            footer
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .background(
            KeyboardCaptureView(onKeyDown: viewModel.handle)
                .frame(width: 0, height: 0)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button("Open Video", action: viewModel.openVideo)
                .keyboardShortcut("o", modifiers: [.command])
                .accessibilityIdentifier("open-video")

            Button(viewModel.isExporting ? "Exporting..." : "Export Clips", action: viewModel.exportClips)
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.state.canExport || viewModel.isExporting)
                .accessibilityIdentifier("export-clips")

            Button("Clear Clips", action: viewModel.clearClips)
                .disabled(viewModel.state.clips.isEmpty)

            Spacer()

            presetSelector

            Text("\(viewModel.state.clips.count) clip(s)")
                .font(.headline)
                .accessibilityLabel("\(viewModel.state.clips.count) clip(s)")
                .accessibilityIdentifier("clip-count")

            if let asset = viewModel.state.asset {
                Text(TimecodeFormatter.displayString(for: viewModel.state.currentTime))
                    .monospacedDigit()
                Text("/")
                    .foregroundStyle(.secondary)
                Text(TimecodeFormatter.displayString(for: asset.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.statusMessage)
                .foregroundStyle(viewModel.state.lastError == nil ? Color.secondary : Color.red)
                .accessibilityLabel(viewModel.statusMessage)
                .accessibilityIdentifier("status-message")

            HStack {
                Text("Space: play/pause")
                Text("Left/Right: +/- 5s")
                Text("Shift+Left/Right: +/- 1 frame")
                Text("I: mark in")
                Text("O: mark out")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)

            if !viewModel.state.clips.isEmpty {
                clipScroller
            }

            selectedClipControls
            tracePanel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ForEach(ExportPreset.allCases) { preset in
                    Group {
                        if viewModel.state.exportPreset == preset {
                            Button(preset.displayName) {
                                viewModel.setExportPreset(preset)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(preset.displayName) {
                                viewModel.setExportPreset(preset)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(minWidth: 118)
                    .accessibilityValue(viewModel.state.exportPreset == preset ? "selected" : "not selected")
                    .accessibilityIdentifier(preset.buttonIdentifier)
                }
            }

            Text("Preset: \(viewModel.state.exportPreset.displayName)")
                .font(.caption.weight(.semibold))
                .accessibilityLabel("Preset: \(viewModel.state.exportPreset.displayName)")
                .accessibilityIdentifier("selected-export-preset")

            Text(viewModel.state.exportPreset.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(viewModel.state.exportPreset.summary)
                .accessibilityIdentifier("export-preset-summary")
        }
    }

    private var clipScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(viewModel.state.clips.enumerated()), id: \.element.id) { index, clip in
                    Button {
                        viewModel.selectClip(clip.id)
                    } label: {
                        Text(
                            "Clip \(index + 1): \(TimecodeFormatter.displayString(for: clip.start)) - \(TimecodeFormatter.displayString(for: clip.end))"
                        )
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(viewModel.state.selectedClipID == clip.id ? Color.accentColor.opacity(0.22) : Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("clip-chip-\(index + 1)")
                }
            }
        }
    }

    @ViewBuilder
    private var selectedClipControls: some View {
        if let selectedClip = viewModel.state.selectedClip {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        "Selected clip: \(TimecodeFormatter.displayString(for: selectedClip.start)) - \(TimecodeFormatter.displayString(for: selectedClip.end))"
                    )
                    .font(.caption.monospacedDigit())

                    HStack(spacing: 10) {
                        Button("Set Start To Playhead") {
                            viewModel.setSelectedClipBoundary(.start)
                        }
                        .accessibilityIdentifier("set-selected-start-to-playhead")

                        Button("Set End To Playhead") {
                            viewModel.setSelectedClipBoundary(.end)
                        }
                        .accessibilityIdentifier("set-selected-end-to-playhead")

                        Button("Delete Clip") {
                            viewModel.deleteSelectedClip()
                        }
                        .accessibilityIdentifier("delete-selected-clip")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("Clip Editing")
            }
        }
    }

    private var tracePanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.traceFileURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if viewModel.recentTraceEvents.isEmpty {
                    Text("No trace events yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.recentTraceEvents.suffix(6).reversed())) { event in
                        Text(event.displayLine)
                            .font(.caption.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Runtime Trace")
        }
    }
}
