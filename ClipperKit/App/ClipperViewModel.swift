import AppKit
import AVFoundation
import Foundation

@MainActor
final class ClipperViewModel: ObservableObject {
    @Published private(set) var state = EditorState()
    @Published private(set) var statusMessage = "Open a video to begin."
    @Published private(set) var isExporting = false
    @Published private(set) var recentTraceEvents: [RuntimeTraceEvent] = []
    @Published private(set) var recentVideoURLs: [URL] = []

    let player: AVPlayer
    let traceFileURL: URL

    private let playbackController: PlaybackControlling
    private let exporter: ClipExporting
    private let tracer: RuntimeTraceRecording
    private let recentDocuments: RecentDocumentManaging
    private let openPanelFactory: @MainActor () -> NSOpenPanel
    private let exportPanelFactory: @MainActor () -> NSOpenPanel

    var hasLoadedVideo: Bool {
        state.asset != nil
    }

    var canUndoClipChange: Bool {
        state.canUndoClipChange
    }

    var canRedoClipChange: Bool {
        state.canRedoClipChange
    }

    init(
        playbackController: PlaybackControlling = AVPlayerPlaybackController(),
        exporter: ClipExporting? = nil,
        tracer: RuntimeTraceRecording = RuntimeTraceStore(),
        recentDocuments: RecentDocumentManaging = AppRecentDocumentManager(),
        initialState: EditorState = EditorState(),
        openPanelFactory: @escaping @MainActor () -> NSOpenPanel = NSOpenPanel.init,
        exportPanelFactory: @escaping @MainActor () -> NSOpenPanel = NSOpenPanel.init
    ) {
        self.playbackController = playbackController
        self.tracer = tracer
        self.exporter = exporter ?? FFmpegClipExporter(tracer: tracer)
        self.recentDocuments = recentDocuments
        self.openPanelFactory = openPanelFactory
        self.exportPanelFactory = exportPanelFactory
        self.player = playbackController.player
        self.traceFileURL = tracer.traceFileURL
        self.state = initialState
        self.recentVideoURLs = SupportedVideoSource.filterRecentDocumentURLs(recentDocuments.recentDocumentURLs)

        playbackController.onSnapshot = { [weak self] snapshot in
            Task { @MainActor in
                self?.apply(.playbackUpdated(snapshot))
            }
        }

        refreshStatus()
        recordTrace(
            category: .diagnostics,
            message: initialState.asset == nil ? "App ready" : "Loaded launch fixture",
            details: initialState.asset?.url.lastPathComponent
        )
    }

    func openVideo() {
        let panel = openPanelFactory()
        panel.title = "Choose a source video"
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        openVideo(at: url)
    }

    func openVideo(at url: URL) {
        Task { @MainActor in
            await loadVideo(url: url)
        }
    }

    func exportClips() {
        guard let sourceURL = state.asset?.url, state.canExport else {
            state.lastError = ExportError.noClips.errorDescription
            refreshStatus()
            return
        }

        let panel = exportPanelFactory()
        panel.title = "Choose an export folder"
        panel.prompt = "Export"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let outputDirectory = panel.url else {
            return
        }

        let clips = state.clips
        let preset = state.exportPreset
        isExporting = true
        refreshStatus()
        recordTrace(
            category: .export,
            message: "Queued export",
            details: "\(clips.count) clip(s) using \(preset.displayName)"
        )

        Task { @MainActor in
            await performExport(sourceURL: sourceURL, clips: clips, outputDirectory: outputDirectory, preset: preset)
        }
    }

    func handle(_ input: KeyboardInput) -> Bool {
        guard let command = KeyboardShortcutInterpreter.command(for: input) else {
            return false
        }

        switch command {
        case .togglePlayback:
            togglePlayback()
        case .seekBackwardFiveSeconds:
            seek(seconds: -5)
        case .seekForwardFiveSeconds:
            seek(seconds: 5)
        case .stepBackwardFrame:
            step(frames: -1)
        case .stepForwardFrame:
            step(frames: 1)
        case .markIn:
            markIn()
        case .markOut:
            markOut()
        case .deleteSelectedClip:
            deleteSelectedClip()
        }

        return true
    }

    func togglePlaybackFromUI() {
        togglePlayback()
    }

    func seekBackwardFromUI() {
        seek(seconds: -5)
    }

    func seekForwardFromUI() {
        seek(seconds: 5)
    }

    func stepBackwardFromUI() {
        step(frames: -1)
    }

    func stepForwardFromUI() {
        step(frames: 1)
    }

    func markInFromUI() {
        markIn()
    }

    func markOutFromUI() {
        markOut()
    }

    func scrubToTimeFromUI(_ time: CMTime) {
        seek(to: time, recordTrace: false)
    }

    func commitScrubToTimeFromUI(_ time: CMTime) {
        seek(to: time, recordTrace: true)
    }

    func selectClip(_ id: UUID?) {
        apply(.selectClip(id))

        if let clip = state.selectedClip {
            recordTrace(
                category: .clip,
                message: "Selected clip",
                details: "\(TimecodeFormatter.displayString(for: clip.start)) - \(TimecodeFormatter.displayString(for: clip.end))"
            )
        }
    }

    func deleteSelectedClip() {
        guard let selectedClip = state.selectedClip else {
            return
        }
        apply(.deleteSelectedClip)
        recordTrace(
            category: .clip,
            message: "Deleted clip",
            details: "\(TimecodeFormatter.displayString(for: selectedClip.start)) - \(TimecodeFormatter.displayString(for: selectedClip.end))"
        )
    }

    func setSelectedClipBoundary(_ boundary: ClipBoundary) {
        let previousError = state.lastError
        apply(.setSelectedClipBoundary(boundary, to: state.currentTime))

        if let error = state.lastError, error != previousError {
            recordTrace(category: .clip, message: "Rejected clip edit", details: error)
            return
        }

        guard let clip = state.selectedClip else {
            return
        }
        let label = boundary == .start ? "Updated clip start" : "Updated clip end"
        recordTrace(
            category: .clip,
            message: label,
            details: "\(TimecodeFormatter.displayString(for: clip.start)) - \(TimecodeFormatter.displayString(for: clip.end))"
        )
    }

    func setExportPreset(_ preset: ExportPreset) {
        apply(.setExportPreset(preset))
        recordTrace(category: .export, message: "Changed export preset", details: preset.displayName)
    }

    func clearClips() {
        apply(.clearClips)
        recordTrace(category: .clip, message: "Cleared clips", details: nil)
    }

    func undoClipChange() {
        let previousSnapshot = state.clipDefinitionSnapshot
        apply(.undoClipChange)
        guard state.clipDefinitionSnapshot != previousSnapshot else {
            return
        }
        recordTrace(category: .clip, message: "Undid clip change", details: clipHistoryTraceDetails())
    }

    func redoClipChange() {
        let previousSnapshot = state.clipDefinitionSnapshot
        apply(.redoClipChange)
        guard state.clipDefinitionSnapshot != previousSnapshot else {
            return
        }
        recordTrace(category: .clip, message: "Redid clip change", details: clipHistoryTraceDetails())
    }

    func clearRecentVideos() {
        recentDocuments.clearRecentDocuments()
        refreshRecentVideos()
        recordTrace(category: .diagnostics, message: "Cleared recent videos", details: nil)
    }

    func loadVideo(url: URL) async {
        guard SupportedVideoSource.supports(url) else {
            state.lastError = SupportedVideoSource.unsupportedMessage
            refreshStatus()
            await appendTrace(
                category: .playback,
                message: "Rejected unsupported video",
                details: url.lastPathComponent
            )
            return
        }

        do {
            let context = try await playbackController.loadVideo(url: url)
            apply(.videoLoaded(context))
            recentDocuments.noteRecentDocument(url)
            refreshRecentVideos()
            await appendTrace(
                category: .playback,
                message: "Loaded video",
                details: url.lastPathComponent
            )
        } catch {
            state.lastError = error.localizedDescription
            refreshStatus()
            await appendTrace(
                category: .playback,
                message: "Failed to load video",
                details: error.localizedDescription
            )
        }
    }

    private func performExport(sourceURL: URL, clips: [ClipSegment], outputDirectory: URL, preset: ExportPreset) async {
        do {
            let exportedFiles = try await exporter.export(
                sourceURL: sourceURL,
                clips: clips,
                outputDirectory: outputDirectory,
                preset: preset
            )
            isExporting = false
            state.lastError = nil
            statusMessage = "Exported \(exportedFiles.count) clip(s) to \(outputDirectory.lastPathComponent)."
            await refreshTraceEvents()
        } catch {
            isExporting = false
            state.lastError = error.localizedDescription
            refreshStatus()
            await refreshTraceEvents()
        }
    }

    private func refreshRecentVideos() {
        recentVideoURLs = SupportedVideoSource.filterRecentDocumentURLs(recentDocuments.recentDocumentURLs)
    }

    private func apply(_ action: EditorAction) {
        var nextState = state
        let effects = EditorReducer.reduce(state: &nextState, action: action)
        state = nextState

        for effect in effects {
            switch effect {
            case let .setPlaying(isPlaying):
                playbackController.setPlaying(isPlaying)
            case let .seek(time):
                playbackController.seek(to: time)
            }
        }

        refreshStatus()
    }

    private func refreshStatus() {
        if isExporting {
            statusMessage = "Exporting \(state.clips.count) clip(s)..."
            return
        }

        if let error = state.lastError, !error.isEmpty {
            statusMessage = error
            return
        }

        if let pendingInPoint = state.pendingInPoint {
            statusMessage = "In point set at \(TimecodeFormatter.displayString(for: pendingInPoint)). Move to the out point and press O."
            return
        }

        if let selectedClip = state.selectedClip {
            statusMessage = "Selected clip \(TimecodeFormatter.displayString(for: selectedClip.start)) - \(TimecodeFormatter.displayString(for: selectedClip.end))."
            return
        }

        if !state.clips.isEmpty {
            statusMessage = "\(state.clips.count) clip(s) ready for export."
            return
        }

        if state.asset != nil {
            statusMessage = "Use Space, arrows, I, and O to define clips."
            return
        }

        statusMessage = "Open a video to begin."
    }

    private func togglePlayback() {
        let previousValue = state.isPlaying
        apply(.togglePlayback)
        guard previousValue != state.isPlaying else {
            return
        }
        recordTrace(
            category: .playback,
            message: state.isPlaying ? "Started playback" : "Paused playback",
            details: TimecodeFormatter.displayString(for: state.currentTime)
        )
    }

    private func seek(seconds: Double) {
        let target = CMTime.clipperSeconds(state.currentTime.secondsValue + seconds)
        seek(to: target, recordTrace: true)
    }

    private func step(frames: Int) {
        guard let asset = state.asset else {
            return
        }

        let target = CMTimeAdd(
            state.currentTime.clamped(lower: .zero, upper: asset.duration),
            CMTimeMultiplyByFloat64(asset.frameDuration, multiplier: Double(frames))
        )
        seek(to: target, recordTrace: true, message: "Stepped frame")
    }

    private func markIn() {
        apply(.markIn)
        guard let pendingInPoint = state.pendingInPoint else {
            return
        }
        recordTrace(
            category: .clip,
            message: "Marked in point",
            details: TimecodeFormatter.displayString(for: pendingInPoint)
        )
    }

    private func markOut() {
        let previousCount = state.clips.count
        let previousError = state.lastError
        apply(.markOut)

        if state.clips.count > previousCount, let clip = state.selectedClip {
            recordTrace(
                category: .clip,
                message: "Created clip",
                details: "\(TimecodeFormatter.displayString(for: clip.start)) - \(TimecodeFormatter.displayString(for: clip.end))"
            )
            return
        }

        if let error = state.lastError, error != previousError {
            recordTrace(category: .clip, message: "Rejected clip change", details: error)
        }
    }

    private func recordTrace(category: TraceCategory, message: String, details: String?) {
        Task { @MainActor [tracer] in
            await tracer.record(category: category, message: message, details: details)
            self.recentTraceEvents = await tracer.recentEvents()
        }
    }

    private func appendTrace(category: TraceCategory, message: String, details: String?) async {
        await tracer.record(category: category, message: message, details: details)
        await refreshTraceEvents()
    }

    private func refreshTraceEvents() async {
        recentTraceEvents = await tracer.recentEvents()
    }

    private func seek(to time: CMTime, recordTrace shouldTrace: Bool, message: String = "Seeked playback") {
        guard let asset = state.asset else {
            return
        }

        let previousTime = state.currentTime
        let clampedTime = time.clamped(lower: .zero, upper: asset.duration)
        playbackController.seek(to: clampedTime)

        state.currentTime = clampedTime
        refreshStatus()

        guard shouldTrace, !state.currentTime.isEqualTo(previousTime) else {
            return
        }

        self.recordTrace(
            category: .playback,
            message: message,
            details: TimecodeFormatter.displayString(for: state.currentTime)
        )
    }

    private func clipHistoryTraceDetails() -> String? {
        if let selectedClip = state.selectedClip {
            return "\(TimecodeFormatter.displayString(for: selectedClip.start)) - \(TimecodeFormatter.displayString(for: selectedClip.end))"
        }

        if let pendingInPoint = state.pendingInPoint {
            return "IN \(TimecodeFormatter.displayString(for: pendingInPoint))"
        }

        if state.clips.isEmpty {
            return "No clips"
        }

        return "\(state.clips.count) clip(s)"
    }
}
