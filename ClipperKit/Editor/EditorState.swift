import AVFoundation
import Foundation

struct VideoAssetContext {
    let url: URL
    let duration: CMTime
    let frameDuration: CMTime
}

extension VideoAssetContext: Equatable {
    static func == (lhs: VideoAssetContext, rhs: VideoAssetContext) -> Bool {
        lhs.url == rhs.url &&
        lhs.duration.isEqualTo(rhs.duration) &&
        lhs.frameDuration.isEqualTo(rhs.frameDuration)
    }
}

struct PlaybackSnapshot {
    let url: URL?
    let currentTime: CMTime
    let duration: CMTime
    let frameDuration: CMTime
    let isPlaying: Bool
}

extension PlaybackSnapshot: Equatable {
    static func == (lhs: PlaybackSnapshot, rhs: PlaybackSnapshot) -> Bool {
        lhs.url == rhs.url &&
        lhs.currentTime.isEqualTo(rhs.currentTime) &&
        lhs.duration.isEqualTo(rhs.duration) &&
        lhs.frameDuration.isEqualTo(rhs.frameDuration) &&
        lhs.isPlaying == rhs.isPlaying
    }
}

struct ClipDefinitionSnapshot {
    var pendingInPoint: CMTime?
    var clips: [ClipSegment]
    var selectedClipID: UUID?
}

extension ClipDefinitionSnapshot: Equatable {
    static func == (lhs: ClipDefinitionSnapshot, rhs: ClipDefinitionSnapshot) -> Bool {
        ((lhs.pendingInPoint == nil && rhs.pendingInPoint == nil) ||
            (lhs.pendingInPoint?.isEqualTo(rhs.pendingInPoint ?? .invalid) ?? false)) &&
        lhs.clips == rhs.clips &&
        lhs.selectedClipID == rhs.selectedClipID
    }
}

struct EditorState {
    static let maximumClipHistoryDepth = 100

    var asset: VideoAssetContext?
    var currentTime: CMTime = .zero
    var isPlaying = false
    var pendingInPoint: CMTime?
    var clips: [ClipSegment] = []
    var selectedClipID: UUID?
    var undoHistory: [ClipDefinitionSnapshot] = []
    var redoHistory: [ClipDefinitionSnapshot] = []
    var exportPreset: ExportPreset = .fastH264
    var lastError: String?

    var canExport: Bool {
        asset != nil && !clips.isEmpty
    }

    var canUndoClipChange: Bool {
        !undoHistory.isEmpty
    }

    var canRedoClipChange: Bool {
        !redoHistory.isEmpty
    }

    var selectedClip: ClipSegment? {
        guard let selectedClipID else {
            return nil
        }
        return clips.first { $0.id == selectedClipID }
    }

    var selectedClipIndex: Int? {
        guard let selectedClipID else {
            return nil
        }
        return clips.firstIndex { $0.id == selectedClipID }
    }

    var clipDefinitionSnapshot: ClipDefinitionSnapshot {
        ClipDefinitionSnapshot(
            pendingInPoint: pendingInPoint,
            clips: clips,
            selectedClipID: selectedClipID
        )
    }
}

extension EditorState: Equatable {
    static func == (lhs: EditorState, rhs: EditorState) -> Bool {
        lhs.asset == rhs.asset &&
        lhs.currentTime.isEqualTo(rhs.currentTime) &&
        lhs.isPlaying == rhs.isPlaying &&
        ((lhs.pendingInPoint == nil && rhs.pendingInPoint == nil) ||
            (lhs.pendingInPoint?.isEqualTo(rhs.pendingInPoint ?? .invalid) ?? false)) &&
        lhs.clips == rhs.clips &&
        lhs.selectedClipID == rhs.selectedClipID &&
        lhs.undoHistory == rhs.undoHistory &&
        lhs.redoHistory == rhs.redoHistory &&
        lhs.exportPreset == rhs.exportPreset &&
        lhs.lastError == rhs.lastError
    }
}

enum ClipBoundary: Equatable, Sendable {
    case start
    case end
}

enum EditorAction: Equatable {
    case videoLoaded(VideoAssetContext)
    case playbackUpdated(PlaybackSnapshot)
    case togglePlayback
    case seekSeconds(Double)
    case seekFrames(Int)
    case markIn
    case markOut
    case selectClip(UUID?)
    case deleteSelectedClip
    case setSelectedClipBoundary(ClipBoundary, to: CMTime)
    case setExportPreset(ExportPreset)
    case clearPendingInPoint
    case clearClips
    case undoClipChange
    case redoClipChange
}

enum EditorEffect: Equatable {
    case setPlaying(Bool)
    case seek(CMTime)

    static func == (lhs: EditorEffect, rhs: EditorEffect) -> Bool {
        switch (lhs, rhs) {
        case let (.setPlaying(left), .setPlaying(right)):
            return left == right
        case let (.seek(left), .seek(right)):
            return left.isEqualTo(right)
        default:
            return false
        }
    }
}
