import AVFoundation

enum EditorReducer {
    static func reduce(state: inout EditorState, action: EditorAction) -> [EditorEffect] {
        switch action {
        case let .videoLoaded(asset):
            state = EditorState(asset: asset)
            return [.seek(.zero), .setPlaying(false)]

        case let .playbackUpdated(snapshot):
            if let url = snapshot.url {
                let duration = snapshot.duration.secondsValue > 0 ? snapshot.duration : (state.asset?.duration ?? .zero)
                let frameDuration = snapshot.frameDuration.secondsValue > 0 ? snapshot.frameDuration : (state.asset?.frameDuration ?? CMTime.clipperSeconds(1.0 / 30.0))
                state.asset = VideoAssetContext(url: url, duration: duration, frameDuration: frameDuration)
            }
            let maximumTime = state.asset?.duration ?? snapshot.duration
            state.currentTime = snapshot.currentTime.clamped(lower: .zero, upper: maximumTime)
            state.isPlaying = snapshot.isPlaying
            return []

        case .togglePlayback:
            guard state.asset != nil else {
                return []
            }
            state.lastError = nil
            state.isPlaying.toggle()
            return [.setPlaying(state.isPlaying)]

        case let .seekSeconds(delta):
            guard let duration = state.asset?.duration else {
                return []
            }
            state.lastError = nil
            let target = CMTime
                .clipperSeconds(state.currentTime.secondsValue + delta)
                .clamped(lower: .zero, upper: duration)
            state.currentTime = target
            return [.seek(target)]

        case let .seekFrames(frameCount):
            let frameDuration = state.asset?.frameDuration.secondsValue ?? (1.0 / 30.0)
            return reduce(state: &state, action: .seekSeconds(Double(frameCount) * frameDuration))

        case .markIn:
            guard state.asset != nil else {
                return []
            }
            let nextPendingInPoint = state.currentTime
            guard !timesEqual(state.pendingInPoint, nextPendingInPoint) else {
                state.lastError = nil
                return []
            }
            pushUndoSnapshot(into: &state)
            state.lastError = nil
            state.pendingInPoint = nextPendingInPoint
            return []

        case .markOut:
            guard let asset = state.asset, let inPoint = state.pendingInPoint else {
                return []
            }
            guard let clip = ClipSegment(start: inPoint, end: state.currentTime).normalized(maximumTime: asset.duration) else {
                state.lastError = "End point must be after the start point."
                return []
            }
            guard !hasOverlap(clip, in: state.clips, ignoringID: nil) else {
                state.lastError = "Clips cannot overlap existing ranges."
                return []
            }
            pushUndoSnapshot(into: &state)
            state.lastError = nil
            state.pendingInPoint = nil
            state.clips.append(clip)
            state.clips.sort { CMTimeCompare($0.start, $1.start) < 0 }
            state.selectedClipID = clip.id
            return []

        case let .selectClip(id):
            state.selectedClipID = id
            state.lastError = nil
            return []

        case .deleteSelectedClip:
            guard let selectedClipIndex = state.selectedClipIndex else {
                return []
            }
            pushUndoSnapshot(into: &state)
            state.clips.remove(at: selectedClipIndex)
            state.lastError = nil

            if state.clips.isEmpty {
                state.selectedClipID = nil
            } else {
                let nextIndex = min(selectedClipIndex, state.clips.count - 1)
                state.selectedClipID = state.clips[nextIndex].id
            }
            return []

        case let .setSelectedClipBoundary(boundary, time):
            guard let asset = state.asset, let selectedClipIndex = state.selectedClipIndex else {
                return []
            }

            var updatedClip = state.clips[selectedClipIndex]
            switch boundary {
            case .start:
                updatedClip = ClipSegment(id: updatedClip.id, start: time, end: updatedClip.end)
            case .end:
                updatedClip = ClipSegment(id: updatedClip.id, start: updatedClip.start, end: time)
            }

            guard let normalizedClip = updatedClip.normalized(maximumTime: asset.duration) else {
                state.lastError = "Clip start must be before clip end."
                return []
            }
            guard !hasOverlap(normalizedClip, in: state.clips, ignoringID: normalizedClip.id) else {
                state.lastError = "Clips cannot overlap existing ranges."
                return []
            }
            guard normalizedClip != state.clips[selectedClipIndex] else {
                state.lastError = nil
                return []
            }

            pushUndoSnapshot(into: &state)
            state.clips[selectedClipIndex] = normalizedClip
            state.clips.sort { CMTimeCompare($0.start, $1.start) < 0 }
            state.selectedClipID = normalizedClip.id
            state.lastError = nil
            return []

        case let .setExportPreset(preset):
            state.exportPreset = preset
            state.lastError = nil
            return []

        case .clearPendingInPoint:
            guard state.pendingInPoint != nil else {
                state.lastError = nil
                return []
            }
            pushUndoSnapshot(into: &state)
            state.pendingInPoint = nil
            state.lastError = nil
            return []

        case .clearClips:
            guard !state.clips.isEmpty || state.pendingInPoint != nil || state.selectedClipID != nil else {
                state.lastError = nil
                return []
            }
            pushUndoSnapshot(into: &state)
            state.clips = []
            state.pendingInPoint = nil
            state.selectedClipID = nil
            state.lastError = nil
            return []

        case .undoClipChange:
            guard let snapshot = state.undoHistory.popLast() else {
                return []
            }
            state.redoHistory.append(state.clipDefinitionSnapshot)
            restore(snapshot, into: &state)
            state.lastError = nil
            return []

        case .redoClipChange:
            guard let snapshot = state.redoHistory.popLast() else {
                return []
            }
            state.undoHistory.append(state.clipDefinitionSnapshot)
            restore(snapshot, into: &state)
            state.lastError = nil
            return []
        }
    }

    private static func hasOverlap(_ clip: ClipSegment, in clips: [ClipSegment], ignoringID: UUID?) -> Bool {
        clips.contains { existingClip in
            guard existingClip.id != ignoringID else {
                return false
            }
            return CMTimeCompare(clip.start, existingClip.end) < 0 &&
                CMTimeCompare(clip.end, existingClip.start) > 0
        }
    }

    private static func pushUndoSnapshot(into state: inout EditorState) {
        state.undoHistory.append(state.clipDefinitionSnapshot)
        if state.undoHistory.count > EditorState.maximumClipHistoryDepth {
            state.undoHistory.removeFirst(state.undoHistory.count - EditorState.maximumClipHistoryDepth)
        }
        state.redoHistory.removeAll()
    }

    private static func restore(_ snapshot: ClipDefinitionSnapshot, into state: inout EditorState) {
        state.pendingInPoint = snapshot.pendingInPoint
        state.clips = snapshot.clips
        state.selectedClipID = snapshot.selectedClipID
    }

    private static func timesEqual(_ lhs: CMTime?, _ rhs: CMTime?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return left.isEqualTo(right)
        default:
            return false
        }
    }
}
